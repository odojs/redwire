fs = require 'fs'
tls = require 'tls'
crypto = require 'crypto'

module.exports = class CertificateStore
  constructor: ->
    @_certs = {}
    @_secureContexts = {}
  
  add: (hostname, options) =>
    scOpts = 
      key: @_getCertData options.key
      cert: @_getCertData options.cert
    scOpts.ca = @_getCertBundleData options.ca if options.ca
    @_secureContexts[hostname] = tls.createSecureContext scOpts
  
  isAvailable: (hostname) => @_secureContexts[hostname]?
  
  getHttpsOptions: (options) =>
    result =
      SNICallback: (hostname, callback) => callback(null, @_secureContexts[hostname])
      key: @_getCertData options.key
      cert: @_getCertData options.cert
    result.ca = [@_getCertData options.ca] if options.ca
    result
  
  getTlsOptions: (options) =>
    result =
      key: @_getCertData options.key
      cert: @_getCertData options.cert
    result.ca = [@_getCertData options.ca] if options.ca
    result

  _getCertBundleData: (pathname) =>
    ca = []
    chain = fs.readFileSync pathname, 'utf8'
    chain = chain.split '\n'
    cert = []
    for line in chain
      if line.length == 0
        continue
      cert.push line
      if line.match /-END CERTIFICATE-/
        ca.push cert.join('\n')
        cert = []
    ca
  
  _getCertData: (pathname) =>
    if pathname
      if pathname instanceof Array
        for path in pathname
          @_getCertData path
      else if fs.existsSync pathname
        fs.readFileSync pathname, 'utf8'
