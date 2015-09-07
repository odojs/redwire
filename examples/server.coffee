fs = require 'fs'
http = require 'http'

#http.globalAgent.keepAlive = yes

finalhandler = require 'finalhandler'
serveStatic = require 'serve-static'

serve = serveStatic '/Users/tcoats/Open/dve/examples'

http
  .createServer (req, res) ->
    serve req, res, finalhandler req, res
  .listen 8080