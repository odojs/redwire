expect = require('chai').expect
RedWire = require '../src/redwire'
http = require 'http'

describe 'Set Host', ->
  testServer = (port, cb) ->
    server = http.createServer (req, res) ->
      res.write ''
      res.end()
      cb req
      server.close()
    server.listen port
  
  it 'should not apply by default', (done) ->
    redwire = new RedWire http: port: 53433
    
    redwire
      .http 'http://localhost:53433'
      .use redwire.proxy 'http://localhost:54674'
    
    testServer 54674, (req) ->
      expect(req.headers['host']).to.be.eql 'localhost:53433'
    
    http.get 'http://localhost:53433', (res) ->
      redwire.close()
      done()
  
  it 'should apply when configured', (done) ->
    redwire = new RedWire http: port: 53434
    
    redwire
      .http 'http://localhost:53434'
      .use redwire.setHost 'example.com'
      .use redwire.proxy 'http://localhost:54675'
    
    testServer 54675, (req) ->
      expect(req.headers['host']).to.be.eql 'example.com'
    
    http.get 'http://localhost:53434', (res) ->
      redwire.close()
      done()
