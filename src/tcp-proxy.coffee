net = require 'net'
tls = require 'tls'
parse_url = require('url').parse

module.exports = class TcpProxy
  constructor: (options, redwire) ->
    @_options = options
    @_redwire = redwire
    
    @_startTcp() if @_options.tcp
    @_startTls() if @_options.tls
  
  _startTcp: =>
    @_tcpServer = net.createServer (socket) =>
      socket.on 'error', (args...) => @_tcpServer.emit 'error', args...
      @_redwire._bindings._tcp.exec {}, socket, @tcpError 'No rules caught tcp connection'
    
    @_tcpServer.on 'error', (err) =>
      console.log err
      #@log.error err, 'TCP Server Error' if @log?
    
    @_tcpServer.listen @_options.tcp.port
  
  _startTls: =>
    @_tlsServer = tls.createServer @certificates.getTlsOptions(@_options.tls), (socket) =>
      socket.on 'error', (args...) => @_tlsServer.emit 'error', args...
      @_redwire._bindings._tls.exec {}, socket, @tlsError 'No rules caught tls connection'
    
    @_tlsServer.on 'error', (err) =>
      console.log err
      #@log.error err, 'TCP Server Error' if @log?
      
    @_tlsServer.listen @_options.tls.port
  
  proxyTcp: (target) => (req, socket, next) =>
    t = target
    t = req.target if !t?
    if t? and typeof t is 'string' and t.indexOf('tcp://')
      t = "tcp://#{t}"
    return @_tcpError req, socket, 'No server to proxy to' if !t?
    
    url = parse_url t
    url =
      host: url.hostname
      port: url.port
    
    proxySock = net
      .connect url
      .on 'error', (args...) => @_tcpServer.emit 'error', args...
      .on 'end', => socket.end()
    proxySock.pipe(socket).pipe(proxySock)
    socket.on 'end', => proxySock.end()
  
  proxyTls: (options, target) => (req, socket, next) =>
    if !target?
      target = options
      options = null
    
    t = target
    t = req.target if !t?
    if t? and t.indexOf('tls://')
      t = "tls://#{t}"
    return @_tlsError req, socket, 'No server to proxy to' if !t?
    
    options = req if !options?
    url = parse_url t
    url =
      host: url.hostname
      port: url.port
    
    proxySock = tls
      .connect options, url
      .on 'error', (args...) => @_tlsServer.emit 'error', args...
    proxySock.pipe(socket).pipe(proxySock)
  
  _tcpError: (req, socket, message) =>
    console.log message
    socket.destroy()
  
  tcpError: (message) => (req, socket, next) =>
    @_tcpError req, socket, message
  
  _tlsError: (req, socket, message) =>
    console.log message
    socket.destroy()
  
  tlsError: (message) => (req, socket, next) =>
    @_tlsError req, socket, message
  
  close: (cb) =>
    @_tcpServer.close() if @_tcpServer?
    @_tlsServer.close() if @_tlsServer?
    cb() if cb?