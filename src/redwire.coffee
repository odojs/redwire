http = require 'http'
https = require 'https'
net = require 'net'
tls = require 'tls'

http_proxy = require 'http-proxy'
parse_url = require('url').parse
format_url = require('url').format

CertificateStore = require './certificate-store'
LoadBalancer = require './load-balancer'
Bindings = require './bindings'

# Copy all of the properties on source to target, recurse if an object
copy = (source, target) ->
  for key, value of source
    if typeof value is 'object'
      target[key] = {} if !target[key]? or typeof target[key] isnt 'object'
      copy value, target[key]
    else
      target[key] = value

module.exports = class RedWire
  constructor: (options) ->
    # Default options
    @_options =
      http:
        port: 8080
        websockets: no
      https: no
      tcp: no
      tls: no
      proxy:
        xfwd: yes
        prependPath: no
    copy options, @_options
    
    @_bindings = @createNewBindings()
    
    @_startHttp() if @_options.http
    @_startHttps() if @_options.https
    @_startTcp() if @_options.tcp
    @_startTls() if @_options.tls
    @_startProxy() if @_options.proxy
  
  _parseSource: (req) =>
    source = parse_url req.url
    source.protocol = 'http:'
    source.host = req.headers.host
    chunks = source.host.split ':'
    source.hostname = chunks[0]
    source.port = chunks[1] or null
    source.href = "#{source.protocol}//#{source.host}#{source.path}"
    source.slashes = yes
    source
  
  _startHttp: =>
    @_httpServer = http.createServer (req, res) =>
      req.source = @_parseSource req
      @_bindings._http.exec req.source.href, req, res, @_error404
    
    if @_options.http.websockets
      @_httpServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req
        @_bindings._httpWs.exec req.source.href, req, socket, head, @_error404
    
    @_httpServer.on 'error', (err) =>
      console.log err
      #@log.error err, 'Server Error' if @log?
    
    @_httpServer.listen @_options.http.port or 8080
  
  _startHttps: =>
    @certificates = new CertificateStore()
    
    @_httpsServer = https.createServer @certificates.getHttpsOptions(@_options.https), (req, res) =>
      req.source = @_parseSource req
      @_bindings._https.exec req.source.href, req, res, @_error404
    
    if @_options.https.websockets
      @_httpsServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req
        @_bindings._httpsWs.exec req.source.href, req, socket, head, @_error404
    
    @_httpsServer.on 'error', (err, req, res) =>
      @_error500 req, res, err
      console.log err
      #@log.error err, 'HTTPS Server Error' if @log?
      
    @_httpsServer.listen @_options.https.port or 8443
  
  _startTcp: =>
    @_tcpServer = net.createServer (socket) =>
      socket.on 'error', (args...) => @_tcpServer.emit 'error', args...
      @_bindings._tcp.exec {}, socket, @tcpError 'No rules caught tcp connection'
    
    @_tcpServer.on 'error', (err) =>
      console.log err
      #@log.error err, 'TCP Server Error' if @log?
    
    @_tcpServer.listen @_options.tcp.port
  
  _startTls: =>
    @_tlsServer = tls.createServer @certificates.getTlsOptions(@_options.tls), (socket) =>
      socket.on 'error', (args...) => @_tlsServer.emit 'error', args...
      @_bindings._tls.exec {}, socket, @tlsError 'No rules caught tls connection'
    
    @_tlsServer.on 'error', (err) =>
      console.log err
      #@log.error err, 'TCP Server Error' if @log?
      
    @_tlsServer.listen @_options.tls.port
  
  _startProxy: =>
    @_proxy = http_proxy.createProxyServer @_options.proxy
    @_proxy.on 'proxyReq', (p, req, res, options) =>
      p.setHeader 'host', req.host if req.host?
    @_proxy.on 'error', (err, req, res) =>
      @_error500 req, res, err if !res.headersSent
      #@log.error err, 'Proxy Error' if @log?
  
  setHost: (host) => (mount, url, req, args..., next) =>
    req.host = host
    next()
  
  sslRedirect: (port) => (mount, url, req, res, next) =>
    target = parse_url req.url
    target.port = port if port?
    target.port = @_options.https.port if @_options.https.port?
    target.hostname = req.source.hostname
    target.protocol = 'https:'
    res.writeHead 302, Location: format_url target
    res.end()
  
  loadBalancer: (options) => new LoadBalancer options
  
  cors: (allowedHosts) => (mount, url, req, res, next) =>
    referer = req.headers.referer
    return next() if !referer?
    return next() unless referer in allowedHosts
    res.setHeader 'Access-Control-Allow-Origin', referer
    res.setHeader 'Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE'
    res.setHeader 'Access-Control-Allow-Headers', 'Content-Type'
    next()
  
  _translateUrl: (mount, target, url) =>
    mount = parse_url mount
    target = parse_url target
    url = parse_url url
    "#{target.pathname}#{url.path[mount.pathname.length..]}"
  
  proxy: (target) => (mount, url, req, res, next) =>
    t = target
    if t? and t.indexOf('http://') isnt 0 and t.indexOf('https://') isnt 0
      t = "http://#{t}"
    t = req.target if !t?
    return @_error500 req, res, 'No server to proxy to' if !t?
    url = @_translateUrl mount, t, url
    #console.log "#{mount} proxy #{req.url} url"
    req.url = url
    @_proxy.web req, res, target: t
  
  proxyWs: (target) => (mount, url, req, socket, head, next) =>
    t = target
    if t? and t.indexOf('http://') isnt 0 and t.indexOf('https://') isnt 0
      t = "http://#{t}"
    t = req.target if !t?
    return @_error500 req, socket, 'No server to proxy to' if !t?
    url = @_translateUrl mount, t, url
    #console.log "#{mount} proxy #{req.url} url"
    req.url = url
    @_proxy.ws req, socket, head, target: t
  
  proxyTcp: (target) => (req, socket, next) =>
    t = target
    t = req.target if !t?
    if t? and typeof t is 'string' and t.indexOf('tcp://')
      t = "tcp://#{t}"
    return @_tcpError req, socket, 'No server to proxy to' if !t?
    
    url = parse_url t
    url =
      host: url.hostname
      port: url.port
    
    proxySock = net
      .connect url
      .on 'error', (args...) => @_tcpServer.emit 'error', args...
      .on 'end', => socket.end()
    proxySock.pipe(socket).pipe(proxySock)
    socket.on 'end', => proxySock.end()
  
  proxyTls: (options, target) => (req, socket, next) =>
    if !target?
      target = options
      options = null
    
    t = target
    t = req.target if !t?
    if t? and t.indexOf('tls://')
      t = "tls://#{t}"
    return @_tlsError req, socket, 'No server to proxy to' if !t?
    
    options = req if !options?
    url = parse_url t
    url =
      host: url.hostname
      port: url.port
    
    proxySock = tls
      .connect options, url
      .on 'error', (args...) => @_tlsServer.emit 'error', args...
    proxySock.pipe(socket).pipe(proxySock)
  
  _error404: (req, res) =>
    result =  message: "No http proxy setup for #{req.source.href}"
    res.writeHead 404, 'Content-Type': 'application/json'
    res.write JSON.stringify result, null, 2
    res.end()
  
  error404: => (mount, url, req, res, next) => @_error404 req, res
  
  _error500: (req, res, err) =>
    result = message: "Internal error for #{req.source.href}", error: err
    res.writeHead 500, 'Content-Type': 'application/json'
    res.write JSON.stringify result, null, 2
    res.end()
  
  error500: => (mount, url, req, res, next) => @_error500 req, res, ''
  
  _tcpError: (req, socket, message) =>
    console.log message
    socket.destroy()
  
  tcpError: (message) => (req, socket, next) =>
    @_tcpError req, socket, message
  
  _tlsError: (req, socket, message) =>
    console.log message
    socket.destroy()
  
  tlsError: (message) => (req, socket, next) =>
    @_tlsError req, socket, message
  
  _redirect301: (req, res, location) =>
    if location.indexOf('http://') isnt 0 and location.indexOf('https://') isnt 0
      location = "http://#{location}"
    res.writeHead 301, Location: location
    res.end()
  
  redirect301: (location) => (mount, url, req, res, next) =>
    @_redirect301 req, res, location
  
  _redirect302: (req, res, location) =>
    if location.indexOf('http://') isnt 0 and location.indexOf('https://') isnt 0
      location = "http://#{location}"
    res.writeHead 302, Location: location
    res.end()
  
  redirect302: (location) => (mount, url, req, res, next) =>
    @_redirect302 req, res, location
  
  http: (url, target) => @_bindings.http url, target
  https: (url, target) => @_bindings.https url, target
  httpWs: (url, target) => @_bindings.httpWs url, target
  httpsWs: (url, target) => @_bindings.httpsWs url, target
  tcp: (target) => @_bindings.tcp target
  tls: (target) => @_bindings.tls target
  removeHttp: (url) => @_bindings.removeHttp url
  removeHttps: (url) => @_bindings.removeHttps url
  removeHttpWs: (url) => @_bindings.removeHttpWs url
  removeHttpsWs: (url) => @_bindings.removeHttpsWs url
  clearHttp: => @_bindings.clearHttp()
  clearHttps: => @_bindings.clearHttps()
  clearHttpWs: => @_bindings.clearHttpWs()
  clearHttpsWs: => @_bindings.clearHttpsWs()
  clearTcp: => @_bindings.clearTcp()
  clearTls: => @_bindings.clearTls()
  clear: => @_bindings.clear()
  
  createNewBindings: => new Bindings @
  setBindings: (bindings) => @_bindings = bindings
  getBindings: => @_bindings
  
  close: (cb) =>
    @_httpServer.close() if @_httpServer?
    @_httpsServer.close() if @_httpsServer?
    @_tcpServer.close() if @_tcpServer?
    @_tlsServer.close() if @_tlsServer?
    @_proxy.close() if @_proxy?
    cb() if cb?
