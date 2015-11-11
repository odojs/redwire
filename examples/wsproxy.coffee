Redwire = require '../'

options =
  http:
    port: 8081
    websockets: yes
redwire = new Redwire options
redwire
  .httpWs 'localhost:8081'
  .use redwire.proxyWs 'http://localhost:8080'
redwire
  .http 'localhost:8081'
  .use redwire.proxy 'http://localhost:8082'