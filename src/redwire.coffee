format_url = require('url').format

LoadBalancer = require './load-balancer'

Bindings = require './bindings'
WebProxy = require './web-proxy'
TcpProxy = require './tcp-proxy'

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
    @_webProxy = new WebProxy @_options, @ if @_options.http? or @_options.https?
    @_tcpProxy = new TcpProxy @_options, @ if @_options.tcp? or @_options.tls?
  
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
  
  
  proxyTcp: (target) => @_tcpProxy.proxyTcp target
  proxyTls: (options, target) => @_tcpProxy.proxyTls options, target
  proxy: (target) => @_webProxy.proxy target
  proxyWs: (target) => @_webProxy.proxyWs target
  
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
    @_webProxy.close() if @_webProxy?
    @_tcpProxy.close() if @_tcpProxy?
    cb() if cb?
