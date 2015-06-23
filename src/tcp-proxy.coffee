net = require 'net'
tls = require 'tls'
parse_url = require('url').parse

module.exports = class TcpProxy
  constructor: (options, bindings) ->
    @_options = options
    @_bindings = bindings
    
    @_startTcp() if @_options.tcp
    @_startTls() if @_options.tls
    
    if @_options.tcp?.dest?
      setTimeout =>
        @_bindings().tcp @_options.tcp.dest
      , 1
    
    if @_options.tls?.dest?
      setTimeout =>
        @_bindings().tls @_options.tls.dest
      , 1
  
  _startTcp: =>
    @_tcpServer = net.createServer (socket) =>
      socket.on 'error', (args...) => @_tcpServer.emit 'error', args...
      @_bindings()._tcp.exec {}, socket, @tcpError 'No rules caught tcp connection'
    
    @_tcpServer.on 'error', @_options.log.error
    
    @_tcpServer.listen @_options.tcp.port
    @_options.log.notice "tcp server listening on port #{@_options.tcp.port}"
  
  _startTls: =>
    @_tlsServer = tls.createServer @certificates.getTlsOptions(@_options.tls), (socket) =>
      socket.on 'error', (args...) => @_tlsServer.emit 'error', args...
      @_bindings()._tls.exec {}, socket, @tlsError 'No rules caught tls connection'
    
    @_tlsServer.on 'error', @_options.log.error
      
    @_tlsServer.listen @_options.tls.port
    @_options.log.notice "tls server listening on port #{@_options.tls.port}"
  
  proxyTcp: (target) => (req, socket, next) =>
    t = target
    t = req.target if !t?
    if t? and typeof t is 'string' and t.indexOf('tcp://')
      t = "tcp://#{t}"
    return next() if !t?
    
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
    return next() if !t?
    
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
    @_options.log.error message
    socket.destroy()
  
  tcpError: (message) => (req, socket, next) =>
    @_tcpError req, socket, message
  
  _tlsError: (req, socket, message) =>
    @_options.log.error message
    socket.destroy()
  
  tlsError: (message) => (req, socket, next) =>
    @_tlsError req, socket, message
  
  close: (cb) =>
    @_tcpServer.close() if @_tcpServer?
    @_tlsServer.close() if @_tlsServer?
    cb() if cb?