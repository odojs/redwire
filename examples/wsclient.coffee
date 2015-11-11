WebSocket = require 'ws'
ws = new WebSocket 'ws://localhost:8081'

ws.on 'open', ->
  console.log 'open'
  #ws.send 'REQUEST'

ws.on 'message', (data, flags) ->
  console.log data
  #ws.send 'REQUEST'

ws.on 'close', ->
  console.log 'close'