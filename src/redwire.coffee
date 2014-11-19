http = require 'http'
https = require 'https'
http_proxy = require 'http-proxy'
parse_url = require('url').parse
format_url = require('url').format

DispatchNode = require './dispatch-node'
CertificateStore = require './certificate-store'
LoadBalancer = require './load-balancer'

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
      proxy:
        xfwd: yes
        prependPath: no
    copy options, @_options
    
    @_httpNode = new DispatchNode()
    @_httpsNode = new DispatchNode()
    @_httpWsNode = new DispatchNode()
    @_httpsWsNode = new DispatchNode()
    
    @_startHttp() if @_options.http
    @_startHttps() if @_options.https
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
      @_httpNode.exec req.source.href, req, res, @_error404
    
    if @_options.http.websockets
      @_httpServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req
        @_httpWsNode.exec req.source.href, req, socket, head, @_error404
    
    @_httpServer.on 'error', (err) =>
      console.log err
      #@log.error err, 'Server Error' if @log?
    
    @_httpServer.listen @_options.http.port or 8080
  
  _startHttps: =>
    @certificates = new CertificateStore()
    
    @_httpsServer = https.createServer @certificates.getServerOptions(@_options.https), (req, res) =>
      src = @_getReqHost req
      target = @_getTarget src, req
      @_proxyWebRequest req, res, target
    
    if @_options.https.websockets
      @_httpsServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req
        @_httpsWsNode.exec req.source.href, req, socket, head, @_error404
    
    @_httpsServer.on 'error', (err, req, res) =>
      @_error500 req, res, err
      console.log err
      #@log.error err, 'HTTPS Server Error' if @log?
      
    @_httpsServer.listen @_options.https.port or 8443
  
  _startProxy: =>
    @_proxy = http_proxy.createProxyServer @_options.proxy
    @_proxy.on 'proxyReq', (p, req, res, options) =>
      p.setHeader 'host', req.host if req.host?
    @_proxy.on 'error', (err, req, res) =>
      @_error500 req, res, err if !res.headersSent
      #@log.error err, 'Proxy Error' if @log?
  
  http: (url, target) =>
    url = "http://#{url}" if url.indexOf('http://') isnt 0
    result = @_httpNode.match url
    return result if !target?
    
    return result.use @proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  https: (url, target) =>
    url = "https://#{url}" if url.indexOf('https://') isnt 0
    result = @_httpsNode.match url
    return result if !target?
    
    return result.use @proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  httpWs: (url, target) =>
    url = "http://#{url}" if url.indexOf('http://') isnt 0
    result = @_httpWsNode.match url
    return result if !target?
    
    return result.use @proxyWs target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  httpsWs: (url, target) =>
    url = "https://#{url}" if url.indexOf('https://') isnt 0
    result = @_httpsWsNode.match url
    return result if !target?
    
    return result.use @proxyWs target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  removeHttp: (url) => @_httpNode.remove url
  removeHttps: (url) => @_httpsNode.remove url
  removeHttpWs: (url) => @_httpWsNode.remove url
  removeHttpsWs: (url) => @_httpsWsNode.remove url
  
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
  
  close: (cb) =>
    @_httpServer.close() if @_httpServer?
    @_httpsServer.close() if @_httpsServer?
    @_proxy.close() if @_proxy?
    cb() if cb?
