expect = require('chai').expect
RedWire = require '../src/redwire'
http = require 'http'
net = require 'net'

describe 'RedWire', ->
  testHttpServer = (port, cb) ->
    server = http.createServer (req, res) ->
      res.write ''
      res.end()
      cb req
      server.close()
    server.listen port
  
  testTcpServer = (port, cb) ->
    server = net.createServer (socket) ->
      socket.write 'success'
      socket.end()
      server.close()
      cb()
    server.listen port
    
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
    
    testHttpServer 54676, (req) ->
      expect(req.headers['host']).to.be.eql 'localhost:53436'
    
    http.get 'http://localhost:53436', (res) ->
      redwire.close()
      done()
  
  it 'should pass through query strings', (done) ->
    redwire = new RedWire http: port: 53439
    
    redwire.http 'localhost:53439', 'localhost:54679'
    
    testHttpServer 54679, (req) ->
      expect(req.headers['host']).to.be.eql 'localhost:53439'
      expect(req.url).to.be.eql '/query?string=should&work'
    
    http.get 'http://localhost:53439/query?string=should&work', (res) ->
      redwire.close()
      done()
  
  it 'should proxy tcp', (done) ->
    redwire = new RedWire tcp: port: 63433
    
    redwire.tcp 'localhost:63423'
    
    failed1 = yes
    failed2 = yes
    testTcpServer 63423, -> failed1 = no
    
    client = net.connect { port: 63433 }, ->
      client.setEncoding 'utf8'
      client.on 'data', (data) ->
        expect(data).to.eql 'success'
        failed2 = no
      client.on 'end', (data) ->
        expect(failed1).to.be.false()
        expect(failed2).to.be.false()
        done()