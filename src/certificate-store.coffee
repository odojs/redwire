fs = require 'fs'
crypto = require 'crypto'

module.exports = class CertificateStore
  constructor: ->
    @_certs = {}
  
  add: (hostname, options) =>
    @_certs[hostname] = crypto
      .createCredentials
        key: @_getCertData options.key
        cert: @_getCertData options.cert
        ca: @_getCertData options.ca
      .context
  
  isAvailable: (hostname) => @_certs[hostname]?
  
  getServerOptions: (options) =>
    result =
      SNICallback: (hostname) => @_certs[hostname]
      key: @_getCertData options.key
      cert: @_getCertData options.cert
    result.ca = [@_getCertData options.ca] if options.ca
    result
  
  _getCertData: (pathname) =>
    if pathname
      if pathname instanceof Array
        for path in pathname
          @_getCertData path
      else if fs.existsSync pathname
        fs.readFileSync pathname, 'utf8'