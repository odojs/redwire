expect = require('chai').expect
LoadBalancer = require '../src/load-balancer'

describe 'Load Balancer', ->
  it 'should return undefined if no servers are configured', ->
    load = new LoadBalancer()
    expect(load.next()).to.be.eql `undefined`
  
  it 'should round robin by default', ->
    load = new LoadBalancer()
    load.add 'http://localhost:6000/'
    load.add 'http://localhost:6001/'
    load.add 'http://localhost:6002/'
    
    expect(load.next()).to.be.eql 'http://localhost:6000/'
    expect(load.next()).to.be.eql 'http://localhost:6001/'
    expect(load.next()).to.be.eql 'http://localhost:6002/'
    expect(load.next()).to.be.eql 'http://localhost:6000/'