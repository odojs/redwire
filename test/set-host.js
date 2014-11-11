// Generated by CoffeeScript 1.8.0
var RedWire, expect, http, testServer;

expect = require('chai').expect;

RedWire = require('../src/redwire');

http = require('http');

testServer = function(port, cb) {
  var server;
  server = http.createServer(function(req, res) {
    res.write('');
    res.end();
    cb(req);
    return server.close();
  });
  return server.listen(port);
};

describe('Set Host', function() {
  it('should not apply by default', function(done) {
    var redwire;
    redwire = new RedWire({
      http: {
        port: 53433
      }
    });
    redwire.http("http://localhost:53433").use(redwire.proxy("http://localhost:54674"));
    testServer(54674, function(req) {
      return expect(req.headers['host']).to.be.eql("localhost:53433");
    });
    return http.get("http://localhost:53433", function(res) {
      redwire.close();
      return done();
    });
  });
  return it('should apply when configured', function(done) {
    var redwire;
    redwire = new RedWire({
      http: {
        port: 53434
      }
    });
    redwire.http("http://localhost:53434").use(redwire.setHost('example.com')).use(redwire.proxy("http://localhost:54675"));
    testServer(54675, function(req) {
      return expect(req.headers['host']).to.be.eql('example.com');
    });
    return http.get("http://localhost:53434", function(res) {
      redwire.close();
      return done();
    });
  });
});
