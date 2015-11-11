WebSocketServer = require('ws').Server
wss = new WebSocketServer port: 8080

wss.on 'connection', (ws) ->
  ws.on 'message', (message) ->
    console.log message

  handle = setInterval ->
    ws.send 'something'
  , 1000
  ws.on 'close', ->
    clearInterval handle