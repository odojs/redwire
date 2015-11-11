os = require 'os'
http = require 'http'

port = 8082
server = http.createServer (req, res) ->
  process.stdout.write '.'
  result =
    server: os.hostname()
    port: port
    host: req.headers['host']
    method: req.method
    url: req.url
  res.end JSON.stringify result, null, 2

server.listen port, ->
  console.log "Home grown http server running on port #{port}"