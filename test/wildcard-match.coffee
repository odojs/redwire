expect = require('chai').expect
RedWire = require '../src/redwire'
http = require 'http'

describe 'RedWire wildcard', ->
  testHttpServer = (port, cb) ->
    server = http.createServer (req, res) ->
      res.write ''
      res.end()
      cb req
      server.close()
    server.listen port

  it 'should allow wildcards', (done) ->
    redwire = new RedWire http: port: 63436

    redwire.http '*', 'localhost:64676'

    sawit = no
    testHttpServer 64676, (req) -> sawit = yes

    http.get 'http://localhost:63436', (res) ->
      redwire.close()
      expect(sawit).to.be.true()
      done()