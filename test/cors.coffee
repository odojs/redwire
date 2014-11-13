expect = require('chai').expect
RedWire = require '../'
http = require 'http'

describe 'CORS', ->
  testServer = (port, cb) ->
    server = http.createServer (req, res) ->
      res.write ''
      res.end()
      cb req
      server.close()
    server.listen port
    
  it 'should not be present when no servers are provided', (done) ->
    redwire = new RedWire http: port: 53437
    
    redwire
      .http 'http://localhost:53437'
      .use redwire.cors([])
      .use redwire.proxy 'http://localhost:54677'
    
    passed = no
    testServer 54677, (req) -> passed = yes
    
    options =
      hostname: 'localhost'
      port: 53437
      headers: referer: 'http://example.com'
    
    http.get options, (res) ->
      expect(res.headers['access-control-allow-origin']).to.be.undefined()
      expect(passed).to.be.true()
      redwire.close()
      done()
    
  it 'should match the referer and return a single domain', (done) ->
    redwire = new RedWire http: port: 53438
    
    redwire
      .http 'http://localhost:53438'
      .use redwire.cors(['http://default.com', 'http://example.com', 'http://test.com'])
      .use redwire.proxy 'http://localhost:54678'
    
    passed = no
    testServer 54678, (req) -> passed = yes
    
    options =
      hostname: 'localhost'
      port: 53438
      headers: referer: 'http://example.com'
    
    http.get options, (res) ->
      expect(res.headers['access-control-allow-origin']).to.be.eql 'http://example.com'
      expect(passed).to.be.true()
      redwire.close()
      done()