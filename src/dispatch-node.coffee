# Recursively dispatch a url based matching execution
# Provides next methods to each handler that require no arguments
module.exports = class DispatchNode
  constructor: (url, createNode) ->
    if !createNode?
      createNode = (url, createNode) -> new DispatchNode url, createNode
    @_createNode = createNode
    
    @_url = url
    @_handlers = []
    @_listeners = []
    @_wildcard = null
  
  _find: (url) =>
    for listener in @_listeners
      return listener if listener.url is url
    null
  
  match: (url) =>
    if url is '*'
      if !@_wildcard?
        @_wildcard = @_createNode '*'
      return @_wildcard
    
    listener = @_find url
    if !listener?
      listener = url: url, node: @_createNode url
      @_listeners.push listener
      # listeners are dispatched most specific to least specific
      @_listeners.sort (a, b) -> b.url.length - a.url.length
    listener.node
  
  remove: (url) =>
    listener = @_find url
    if listener?
      index = @_listeners.indexOf listener
      @_listeners.splice index, 1
    @
  
  clear: =>
    @_handlers = []
    @_listeners = []
    @_wildcard = null
  
  use: (handler) =>
    if Array.isArray handler
      @use h for h in handler
    else
      @_handlers.push handler
    @
  
  _dispatch: (items, args, next, method) ->
    # copy so we aren't confused by asyc changes
    items = items[..]
    index = 0
    exec = ->
      return next args... if index >= items.length
      item = items[index]
      index++
      method item, args, exec
    exec()
  
  _dispatchHandlers: (url, args..., next) =>
    @_dispatch @_handlers, args, next, (item, args, next) =>
      item @_url, url, args..., next
  
  _dispatchListeners: (url, args..., next) =>
    @_dispatch @_listeners, args, next, (item, args, next) ->
      # Match against the url
      return next() unless url.indexOf(item.url) is 0
      item.node.exec url, args..., next
  
  exec: (url, args..., next) =>
    @_dispatchHandlers url, args..., =>
      @_dispatchListeners url, args..., =>
        return next args... if !@_wildcard?
        @_wildcard.exec url, args..., next