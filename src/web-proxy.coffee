http = require 'http'
https = require 'https'
http2 = require 'http2'
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
    @_startHttp2() if @_options.http2
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

    if @_options.http2?.routes?
      setTimeout =>
        for source, target of @_options.http2.routes
          @_bindings().http2 source, target
      , 1

  _parseSource: (req, protocol, hostname, port) =>
    source = parse_url req.url
    source.protocol = protocol
    source.host = req.headers.host
    if source.host
      chunks = source.host.split ':'
    else
      chunks = [ hostname, port ]
    source.hostname = chunks[0]
    source.port = chunks[1] or null
    source.href = "#{source.protocol}//#{source.host}#{source.path}"
    source.slashes = yes
    source

  _parseHostPort: (options, defaulthost, defaultport) =>
    result =
      port: defaultport
      hostname: defaulthost
    if options.port?
      if typeof options.port is 'string' and options.port.indexOf(':') isnt -1
        chunks = options.port.split ':'
        result.hostname = chunks[0]
        result.port = chunks[1]
      else
        result.port = options.port

    if options.hostname?
      if typeof options.hostname is 'string' and options.hostname.indexOf(':') isnt -1
        chunks = options.hostname.split ':'
        result.hostname = chunks[0]
        result.port = chunks[1]
      else
        result.hostname = options.hostname

    result

  _translateUrl: (mount, target, url) =>
    mount = parse_url mount
    target = parse_url target
    url = parse_url url
    "#{target.pathname}#{url.path[mount.pathname.length..]}"

  _startHttp: =>
    bind = @_parseHostPort @_options.http, '0.0.0.0', 8080
    @_options.http.port = bind.port
    @_options.http.hostname = bind.hostname

    @_httpServer = http.createServer (req, res) =>
      req.source = @_parseSource req, 'http:', @_options.http.hostname, @_options.http.port
      @_bindings()._http.exec req.source.href, req, res, @_error404

    if @_options.http.websockets
      @_options.log.notice 'http server configured for websockets'
      @_httpServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req, 'http:', @_options.http.hostname, @_options.http.port
        @_bindings()._httpWs.exec req.source.href, req, socket, head, @_error404

    @_httpServer.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res?
      @_options.log.error err
      try res.end() if res?

    @_httpServer.listen @_options.http.port, @_options.http.hostname
    @_options.log.notice "http server listening on #{@_options.http.hostname}:#{@_options.http.port}"

  _startHttps: =>
    @certificates = new CertificateStore()

    bind = @_parseHostPort @_options.https, '0.0.0.0', 8443
    @_options.https.port = bind.port
    @_options.https.hostname = bind.hostname

    @_httpsServer = https.createServer @certificates.getHttpsOptions(@_options.https), (req, res) =>
      req.source = @_parseSource req, 'https:', @_options.https.hostname, @_options.https.port
      @_bindings()._https.exec req.source.href, req, res, @_error404

    if @_options.https.websockets
      @_options.log.notice "https server configured for websockets"
      @_httpsServer.on 'upgrade', (req, socket, head) =>
        req.source = @_parseSource req, 'https:', @_options.https.hostname, @_options.https.port
        @_bindings()._httpsWs.exec req.source.href, req, socket, head, @_error404

    @_httpsServer.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res?
      @_options.log.error err
      try res.end() if res?

    @_httpsServer.listen @_options.https.port, @_options.https.hostname
    @_options.log.notice "https server listening on #{@_options.https.hostname}:#{@_options.https.port}"

  _startHttp2: =>
    @certificates = new CertificateStore()

    bind = @_parseHostPort @_options.http2, '0.0.0.0', 8443
    @_options.http2.port = bind.port
    @_options.http2.hostname = bind.hostname

    @_http2Server = http2.createServer @certificates.getHttpsOptions(@_options.http2), (req, res) =>
      req.connection =
        encrypted = yes
      req.source = @_parseSource req, 'https:', @_options.http2.hostname, @_options.http2.port
      @_bindings()._http2.exec req.source.href, req, res, @_error404

    @_http2Server.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res?
      @_options.log.error err
      try res.end() if res?

    @_http2Server.listen @_options.http2.port, @_options.http2.hostname
    @_options.log.notice "http2 server listening on #{@_options.http2.hostname}:#{@_options.http2.port}"

  _startProxy: =>
    @_proxy = http_proxy.createProxyServer @_options.proxy
    @_proxy.on 'proxyReq', (p, req, res, options) =>
      p.setHeader 'connection', 'keep-alive' if @_options.proxy?.keepAlive
      p.setHeader 'host', req.host if req.host?
    @_proxy.on 'proxyRes', (p, req, res) =>
      if req.httpVersionMajor is 2
        delete p.headers.connection
    @_proxy.on 'error', (err, req, res) =>
      @_error500 req, res, err if req? and res? !res.headersSent
      @_options.log.error err
      try res.end() if res?

  proxy: (target) => (mount, url, req, res, next) =>
    t = target
    if t? and t.indexOf('http://') isnt 0 and t.indexOf('https://') isnt 0
      t = "http://#{t}"
    t = req.target if !t?
    return next() if !t?
    url = @_translateUrl mount, t, url
    @_options.log.notice "#{mount} proxy #{req.url} url"
    req.url = url
    @_proxy.web req, res, target: t

  proxyWs: (target) => (mount, url, req, socket, head, next) =>
    t = target
    if t? and t.indexOf('http://') isnt 0 and t.indexOf('https://') isnt 0
      t = "http://#{t}"
    t = req.target if !t?
    return next() if !t?
    url = @_translateUrl mount, t, url
    @_options.log.notice "#{mount} proxy #{req.url} url"
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
    referer = parse_url referer
    referer = format_url
      protocol: referer.protocol
      hostname: referer.hostname
      port: referer.port
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

  _redirectParseUrl: (url) =>
    if url.indexOf('http://') isnt 0 and url.indexOf('https://') isnt 0
      url = "http://#{url}"
    url

  _redirect: (req, res, code, location) =>
    res.writeHead code, Location: location
    res.end()

  _redirect301absolute: (req, res, location) =>
    @_redirect req, res, 301, @_redirectParseUrl location

  redirect301absolute: (location) => (mount, url, req, res, next) =>
    @_redirect req, res, 301, @_redirectParseUrl location

  _redirect302absolute: (req, res, location) =>
    @_redirect req, res, 302, @_redirectParseUrl location

  redirect302absolute: (location) => (mount, url, req, res, next) =>
    @_redirect req, res, 302, @_redirectParseUrl location

  _redirectParseRel: (location, url) =>
    target = @_redirectParseUrl location
    target += url
    target

  _redirect301: (req, res, location) =>
    @_redirect req, res, 301, @_redirectParseRel location, req.url

  redirect301: (location) => (mount, url, req, res, next) =>
    @_redirect req, res, 301, @_redirectParseRel location, req.url

  _redirect302: (req, res, location) =>
    @_redirect req, res, 302, @_redirectParseRel location, req.url

  redirect302: (location) => (mount, url, req, res, next) =>
    @_redirect req, res, 302, @_redirectParseRel location, req.url

  close: (cb) =>
    @_httpServer.close() if @_httpServer?
    @_httpsServer.close() if @_httpsServer?
    @_http2Server.close() if @_http2Server?
    @_proxy.close() if @_proxy?
    cb() if cb?
