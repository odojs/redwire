expect = require('chai').expect
DispatchNode = require '../src/dispatch-node'

describe 'Dispatcher Node', ->
  it 'should exec with no nodes', ->
    node = new DispatchNode()
    node.exec 'http://localhost/', ->
  
  it 'should exec all top level handlers', ->
    node = new DispatchNode()
    count = 0
  
    node.use (mount, url, next) ->
      count++
      next()
    
    node.use (mount, url, next) ->
      count++
      next()
    
    node.exec 'http://localhost/', ->
    expect(count).to.be.eql 2
  
  it 'should match urls', ->
    node = new DispatchNode()
    count = 0
    
    node.match('http://localhost/').use (mount, url, next) ->
      count++
      next()
      
    node.match('http://example.com/').use (mount, url, next) ->
      count++
      next()
    
    node.exec 'http://localhost/', ->
    expect(count).to.be.eql 1
  
  it 'should recursively match urls', ->
    node = new DispatchNode()
    count = 0
    
    node.match('http://localhost/').match('http://localhost/').use (mount, url, next) ->
      count++
      next()
      
    node.match('http://example.com/').use (mount, url, next) ->
      count++
      next()
    
    node.exec 'http://localhost/', ->
    expect(count).to.be.eql 1
  
  it 'should match specific urls first', ->
    node = new DispatchNode()
    count = 0
    
    node
      .match('http://localhost/')
      .use (mount, url, next) ->
        count++
        expect(count).to.be.eql 2
        next()
    
    node
      .match('http://localhost/specific')
      .use (mount, url, next) ->
        count++
        expect(count).to.be.eql 1
        next()
      
    node.match('http://example.com/').use (mount, url, next) ->
      count++
      next()
    
    node.exec 'http://localhost/specific', ->
    expect(count).to.be.eql 2
  
  it 'should run top level handlers first', ->
    node = new DispatchNode()
    count = 0
    
    node.use (mount, url, next) ->
      count++
      expect(count).to.be.eql 1
      next()
    
    node
      .match('http://localhost/specific')
      .use (mount, url, next) ->
        count++
        expect(count).to.be.eql 2
        next()
      
    node.match('http://example.com/').use (mount, url, next) ->
      count++
      next()
    
    node.exec 'http://localhost/specific', ->
    expect(count).to.be.eql 2
  
  it 'should allow arrays of handlers', ->
    node = new DispatchNode()
    count = 0
    
    handler = (mount, url, next) ->
      count++
      next()
    
    node.use [handler, handler]
    
    node.exec 'http://localhost/', ->
      expect(count).to.be.eql 2