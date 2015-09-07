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
      http: no
      https: no
      http2: no
      tcp: no
      tls: no
      proxy:
        xfwd: yes
        prependPath: no
      log:
        debug: ->
        notice: ->
        error: (err) ->
          if err.stack
            console.error err.stack
          else
            console.error err
    
    copy options, @_options
    
    @_bindings = @createNewBindings()
    if @_options.http? or @_options.https? or @_options.http2?
      @_webProxy = new WebProxy @_options, => @_bindings
    if @_options.tcp? or @_options.tls?
      @_tcpProxy = new TcpProxy @_options, => @_bindings
  
  # Expose middleware
  setHost: (args...) => @_webProxy.setHost args...
  sslRedirect: (args...) => @_webProxy.sslRedirect args...
  loadBalancer: (args...) => @_webProxy.loadBalancer args...
  cors: (args...) => @_webProxy.cors args...
  error404: (args...) => @_webProxy.error404 args...
  error500: (args...) => @_webProxy.error500 args...
  redirect301: (args...) => @_webProxy.redirect301 args...
  redirect302: (args...) => @_webProxy.redirect302 args...
  redirect301relative: (args...) => @_webProxy.redirect301relative args...
  redirect302relative: (args...) => @_webProxy.redirect302relative args...
  
  # Expose proxy endpoints
  proxy: (args...) => @_webProxy.proxy args...
  proxyWs: (args...) => @_webProxy.proxyWs args...
  proxyTcp: (args...) => @_tcpProxy.proxyTcp args...
  proxyTls: (args...) => @_tcpProxy.proxyTls args...
  
  # Register bindings
  http: (args...) => @_bindings.http args...
  https: (args...) => @_bindings.https args...
  http2: (args...) => @_bindings.http2 args...
  httpWs: (args...) => @_bindings.httpWs args...
  httpsWs: (args...) => @_bindings.httpsWs args...
  tcp: (args...) => @_bindings.tcp args...
  tls: (args...) => @_bindings.tls args...
  
  # Manage bindings
  removeHttp: (args...) => @_bindings.removeHttp args...
  removeHttps: (args...) => @_bindings.removeHttps args...
  removeHttp2: (args...) => @_bindings.removeHttp2 args...
  removeHttpWs: (args...) => @_bindings.removeHttpWs args...
  removeHttpsWs: (args...) => @_bindings.removeHttpsWs args...
  clearHttp: => @_bindings.clearHttp()
  clearHttps: => @_bindings.clearHttps()
  clearHttp2: => @_bindings.clearHttp2()
  clearHttpWs: => @_bindings.clearHttpWs()
  clearHttpsWs: => @_bindings.clearHttpsWs()
  clearTcp: => @_bindings.clearTcp()
  clearTls: => @_bindings.clearTls()
  clear: => @_bindings.clear()
  createNewBindings: => new Bindings @
  setBindings: (bindings) => @_bindings = bindings
  getBindings: => @_bindings
  
  close: (cb) =>
    try
      @_webProxy.close() if @_webProxy?
      @_tcpProxy.close() if @_tcpProxy?
    catch e
    cb() if cb?
