parse_url = require('url').parse

DispatchNode = require './dispatch-node'

module.exports = class Bindings
  constructor: (redwire) ->
    @_redwire = redwire
    @_http = new DispatchNode()
    @_https = new DispatchNode()
    @_httpWs = new DispatchNode()
    @_httpsWs = new DispatchNode()
  
  http: (url, target) =>
    url = "http://#{url}" if url.indexOf('http://') isnt 0
    result = @_http.match url
    return result if !target?
    
    return result.use @_redwire.proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  https: (url, target) =>
    url = "https://#{url}" if url.indexOf('https://') isnt 0
    result = @_https.match url
    return result if !target?
    
    return result.use @_redwire.proxy target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  httpWs: (url, target) =>
    url = "http://#{url}" if url.indexOf('http://') isnt 0
    result = @_httpWs.match url
    return result if !target?
    
    return result.use @_redwire.proxyWs target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  httpsWs: (url, target) =>
    url = "https://#{url}" if url.indexOf('https://') isnt 0
    result = @_httpsWs.match url
    return result if !target?
    
    return result.use @_redwire.proxyWs target if typeof target is 'string'
    return result.use target if typeof target is 'function'
    
    throw Error 'target not a known type'
  
  removeHttp: (url) => @_http.remove url
  removeHttps: (url) => @_https.remove url
  removeHttpWs: (url) => @_httpWs.remove url
  removeHttpsWs: (url) => @_httpsWs.remove url