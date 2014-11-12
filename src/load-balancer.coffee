module.exports = class LoadBalancer
  constructor: (options) ->
    # Default options
    @_options =
      method: 'roundrobin'
    @_options.method = options.method if options?.method?
    
    @_servers = []
    @_index = 0
  
  add: (target) =>
    if target.indexOf('http://') isnt 0 and target.indexOf('https://') isnt 0
      target = "http://#{target}"
    @_servers.push target
    @
  
  remove: (target) =>
    if target.indexOf('http://') isnt 0 and target.indexOf('https://') isnt 0
      target = "http://#{target}"
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