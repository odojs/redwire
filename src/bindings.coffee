parse_url = require('url').parse

DispatchNode = require './dispatch-node'
UseNode = require './use-node'

module.exports = class Bindings
  constructor: (redwire) ->
    @_redwire = redwire
    @_http = new DispatchNode()
    @_https = new DispatchNode()
    @_http2 = new DispatchNode()
    @_httpWs = new DispatchNode()
    @_httpsWs = new DispatchNode()
    @_tcp = new UseNode()
    @_tls = new UseNode()
  
  http: (url, target) =>
    url = "http://#{url}" if url isnt '*' and url.indexOf('http://') isnt 0
    result = @_http.match url
    return result if !target?
    
    return result.use @_redwire.proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  https: (url, target) =>
    url = "https://#{url}" if url isnt '*' and url.indexOf('https://') isnt 0
    result = @_https.match url
    return result if !target?
    
    return result.use @_redwire.proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  http2: (url, target) =>
    url = "https://#{url}" if url isnt '*' and url.indexOf('https://') isnt 0
    result = @_http2.match url
    return result if !target?
    
    return result.use @_redwire.proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  httpWs: (url, target) =>
    url = "http://#{url}" if url isnt '*' and url.indexOf('http://') isnt 0
    result = @_httpWs.match url
    return result if !target?
    
    return result.use @_redwire.proxyWs target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  httpsWs: (url, target) =>
    url = "https://#{url}" if url isnt '*' and url.indexOf('https://') isnt 0
    result = @_httpsWs.match url
    return result if !target?
    
    return result.use @_redwire.proxyWs target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  tcp: (target) =>
    return @_tcp if !target?
    return @_tcp.use @_redwire.proxyTcp target if typeof target is 'string'
    return @_tcp.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  tls: (options, target) =>
    throw Error 'target not defined' if !target?
    return @_tls.use @_redwire.proxyTls target if typeof target is 'string'
    return @_tls.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  removeHttp: (url) => @_http.remove url
  removeHttps: (url) => @_https.remove url
  removeHttp2: (url) => @_http2.remove url
  removeHttpWs: (url) => @_httpWs.remove url
  removeHttpsWs: (url) => @_httpsWs.remove url
  
  clearHttp: => @_http.clear()
  clearHttps: => @_https.clear()
  clearHttp2: => @_http2.clear()
  clearHttpWs: => @_httpWs.clear()
  clearHttpsWs: => @_httpsWs.clear()
  clearTcp: => @_tcp.clear()
  clearTls: => @_tls.clear()
  
  clear: =>
    @clearHttp()
    @clearHttps()
    @clearHttp2()
    @clearHttpWs()
    @clearHttpsWs()
    @clearTcp()
    @clearTls()