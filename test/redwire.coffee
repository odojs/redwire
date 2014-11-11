expect = require('chai').expect
RedWire = require '../src/redwire'
http = require 'http'

testServer = (port, cb) ->
  server = http.createServer (req, res) ->
    res.write ''
    res.end()
    cb req
    server.close()
  server.listen port

describe 'RedWire', ->
  it 'should have sensible defaults', ->
    redwire = new RedWire()
    redwire.close()
  
  it 'should autoprefix source urls with http:// if absent', ->
    redwire = new RedWire http: port: 53435
    passed = no
    redwire.http 'example.com', (mount, url, req, res, next) ->
      expect(url).to.be.eql 'http://example.com/test'
      passed = yes
    redwire.http('example.com').exec 'http://example.com/test'
    expect(passed).to.be.eql yes
  
  it 'should autoprefix target urls with http:// if absent', (done) ->
    redwire = new RedWire http: port: 53436
    
    redwire.http 'localhost:53436', 'localhost:54676'
    
    testServer 54676, (req) ->
      expect(req.headers['host']).to.be.eql 'localhost:53436'
    
    http.get 'http://localhost:53436', (res) ->
      redwire.close()
      done()