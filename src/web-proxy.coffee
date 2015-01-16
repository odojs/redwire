http = require 'http'
https = require 'https'
http_proxy = require 'http-proxy'
parse_url = require('url').parse
format_url = require('url').format

CertificateStore = require './certificate-store'
LoadBalancer = require './load-balancer'

module.exports = class WebProxy
  constructor: (options, bindings) ->
    @_options = options
    @_bindings = bindings
    
    @_startHttp() if @_options.http
    @_startHttps() if @_options.https
    @_startProxy() if @_options.proxy
    
    if @_options.http?.routes?
      setTimeout =>
        for source, target of @_options.http.routes
          @_bindings().http source, target
      , 1
    
    if @_options.https?.routes?
      setTimeout =>
        for source, target of @_options.https.routes
          @_bindings().https source, target
      , 1
  
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
  
  _translateUrl: (mount, target, url) =>
    mount = parse_url mount
    target = parse_url target
    url = parse_url url
    "#{target.pathname}#{url.path[mount.pathname.length..]}"
  
  _startHttp: =>
    @_options.http.port = @_options.http.port or 8080
    if @_options.http.port.indexOf(':') isnt -1
      chunks = @_options.http.port.split ':'
      @_options.http.hostname = chunks[0]
      @_options.http.port = chunks[1]
    
    @_httpServer = http.createServer (req, res) =>
      req.source = @_parseSource req
      @_bindings()._http.exec req.source.href, req, res, @_error404
    
    if @_options.http.websockets
      @_options.log.notice 'http server configured for websockets'
      @_httpServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req
        @_bindings()._httpWs.exec req.source.href, req, socket, head, @_error404
    
    @_httpServer.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res?
      @_options.log.error err
    
    if @_options.http.hostname?
      @_httpServer.listen @_options.http.port, @_options.http.hostname
    else
      @_httpServer.listen @_options.http.port
    @_options.log.notice "http server listening on port #{@_options.http.port or 8080}"
  
  _startHttps: =>
    @certificates = new CertificateStore()
    
    @_options.https.port = @_options.https.port or 8443
    if @_options.https.port.indexOf(':') isnt -1
      chunks = @_options.https.port.split ':'
      @_options.https.hostname = chunks[0]
      @_options.https.port = chunks[1]
    
    @_httpsServer = https.createServer @certificates.getHttpsOptions(@_options.https), (req, res) =>
      req.source = @_parseSource req
      @_bindings()._https.exec req.source.href, req, res, @_error404
    
    if @_options.https.websockets
      @_options.log.notice "https server configured for websockets"
      @_httpsServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req
        @_bindings()._httpsWs.exec req.source.href, req, socket, head, @_error404
    
    @_httpsServer.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res?
      @_options.log.error err
    
    if @_options.https.hostname?
      @_httpsServer.listen @_options.https.port, @_options.https.hostname
    else
      @_httpsServer.listen @_options.https.port
    @_options.log.notice "https server listening on port #{@_options.https.port}"
  
  _startProxy: =>
    @_proxy = http_proxy.createProxyServer @_options.proxy
    @_proxy.on 'proxyReq', (p, req, res, options) =>
      p.setHeader 'host', req.host if req.host?
    @_proxy.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res? !res.headersSent
      @_options.log.error err
  
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
  
  setHost: (host) => (mount, url, req, args..., next) =>
    req.host = host
    next()
  
  loadBalancer: (options) => new LoadBalancer options
  
  sslRedirect: (port) => (mount, url, req, res, next) =>
    target = parse_url req.url
    target.port = port if port?
    target.port = @_options.https.port if @_options.https.port?
    target.hostname = req.source.hostname
    target.protocol = 'https:'
    res.writeHead 302, Location: format_url target
    res.end()
  
  cors: (allowedHosts) => (mount, url, req, res, next) =>
    referer = req.headers.referer
    return next() if !referer?
    return next() unless referer in allowedHosts
    res.setHeader 'Access-Control-Allow-Origin', referer
    res.setHeader 'Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE'
    res.setHeader 'Access-Control-Allow-Headers', 'Content-Type'
    next()
  
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