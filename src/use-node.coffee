# Recursively dispatch a url based matching execution
# Provides next methods to each handler that require no arguments
module.exports = class DispatchNode
  constructor: ->
    @_handlers = []
  
  use: (handler) =>
    if Array.isArray handler
      @use h for h in handler
    else
      @_handlers.push handler
    @
  
  clear: =>
    @_handlers = []
  
  exec: (args..., next) =>
    # copy so we aren't confused by asyc changes
    items = @_handlers[..]
    index = 0
    exec = ->
      return next args... if index >= items.length
      item = items[index]
      index++
      item args..., exec
    exec()