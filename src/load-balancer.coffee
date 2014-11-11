# Copy all of the properties on source to target, recurse if an object
copy = (source, target) ->
  for key, value of source
    if typeof value is 'object'
      target[key] = {} if !target[key]? or typeof target[key] isnt 'object'
      copy value, target[key]
    else
      target[key] = value

module.exports = class LoadBalancer
  constructor: (options) ->
    # Default options
    @_options =
      method: 'roundrobin'
    copy options, @_options
    
    @_servers = []
    @_index = 0
  
  add: (target) =>
    if target.indexOf('http://') isnt 0 and target.indexOf('https://') isnt 0
      target = "http://#{t}"
    @_servers.push target
    @
  
  remove: (target) =>
    if target.indexOf('http://') isnt 0 and target.indexOf('https://') isnt 0
      target = "http://#{t}"
    @_servers.remove target
    @
  
  next: =>
    @_index = @_index % @_servers.length
    result = @_servers[@_index]
    @_index++
    result
  
  distribute: => (mount, url, req, res, next) =>
    req.target = @next()
    next()