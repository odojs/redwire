# RedWire Reverse Proxy

A dynamic, high performance, load balancing reverse proxy.

A reverse proxy accepts web requests and dispatches these out to other web servers based on the host header. This is identical to Apache's mod_proxy and nginx's proxy_pass.

RedWire can replace nginx in many situations.

RedWire supports:
- HTTP
- HTTPS / SSL through SNI (sorry IE6)
- websockets over http and https
- changing configuration at runtime
- custom functions (middleware)
- Node.js v0.12 / iojs

[![BuildStatus](https://secure.travis-ci.org/metocean/redwire.png?branch=master)](http://travis-ci.org/metocean/redwire)
[![NPM version](https://badge.fury.io/js/redwire.svg)](http://badge.fury.io/js/redwire)

## Install

```sh
npm install redwire
```

RedWire only depends on the excellent [node-http-proxy](https://github.com/nodejitsu/node-http-proxy) and has been heavily inspired by the fantastic [redbird reverse proxy](https://github.com/OptimalBits/redbird).

## Examples

```js
var RedWire = require('redwire');
var redwire = new RedWire({
    // more configuration is available, see below
    http: { port: 80 }
});


// proxy requests for example.com to port 3000 locally
redwire.http('http://example.com').use(redwire.proxy('http://127.0.0.1:3000'));
// a shorthand form is available
redwire.http('example.com', '127.0.0.1:3000');


// proxy to another server with a different host header
// paths can be used as part of the proxy, longer paths are matched first
redwire.http('example.com/api')
    .use(redwire.setHost('testapi.com'))
    .use(redwire.proxy('testapi.com'));


// paths can also be used on the destination
redwire.http('example.com/awesomeimage.png', 'test.com/wp-upload/long/path/IMG0234.png');


// some helpful middleware has been provided
redwire.http('example.com/expired', redwire.error404());
redwire.http('example.com/old', redwire.redirect301('example.com/new'));
redwire.http('example.com', redwire.sslRedirect());


// you can write your own middleware
redwire.http('example.com/api')
    .use(function (mount, url, req, res, next) {
        // mount is 'example.com/api' in this example
        // url is the requested url - something like 'example.com/api/v0/user'
        // req and res are generic NodeJs http request and response objects
        // next is a function to call if you want to continue the chain
        next()
    })
    .use(redwire.proxy('testapi.com'));


// a single middleware can be used for an entire domain
example = redwire.http('example.com')
    .use(function (mount, url, req, res, next) {
        // example logging middleware
        // authentication is possible too
        console.log(url);
        next()
    });
// additional 'matches' can be registered
example.match('example.com/blog').use(redwire.proxy('example.wordpress.com'));
example.match('example.com/api').use(redwire.proxy('testapi.com'));


// balance load across several servers
load = redwire.loadBalancer()
    .add('localhost:6000')
    .add('localhost:6001')
    .add('localhost:6002');
redwire.http('example.com')
    .use(load.distribute())
    .use(redwire.proxy());
// adjust servers at runtime
load.remove('localhost:6000');
```

## Configuration

```js
// defaults are shown
var RedWire = require('redwire');
var options = {
    http: {
        port: 8080,
        websockets: no
    },
    https: no,
    proxy: {
        xfwd: yes,
        prependPath: no,
        keepAlive: no
    },
    log: {
        debug: function() {},
        notice: function() {},
        error: function(err) {
            if (err.stack) {
                console.error(err.stack);
            } else {
                console.error(err);
            }
        }
    }
};
var redwire = new RedWire(options);
```

### HTTP Configuration

When websockets are enabled use `redwire.httpWs` to setup routes and middleware for websocket requests.
RedWire is often most useful handing request on port 80. If this is required your NodeJs application will need to run as root.

### HTTPS Configuration

SNI (multiple ssl certificates) is supported by Internet Explorer 7 and above.

```js
// a default certificate is required
var RedWire = require('redwire');
var options = {
    https: {
        port: 443,
        key: 'path/to/key.pem',
        cert: 'path/to/cert.pem',
        ca: 'path/to/ca.pem (optional)'
    }
};
var redwire = new RedWire(options);

// additional certificates can be added per host (optional)
redwire.certificates.add('example.com', {
    key: 'path/to/key.pem',
    cert: 'path/to/cert.pem',
    ca: 'path/to/ca.pem (optional)'
});

redwire.https('example.com', 'localhost:3000');
```

### Proxy Configuration

```js
var RedWire = require('redwire');
var options = {
    proxy: {
        prependPath: no,
        xfwd: yes
    }
};
var redwire = new RedWire(options);
```

The whole options.proxy structure is passed to node-http-proxy so any options can be passed through. This for experts as changing things may interfere with RedWire's operation. [A list of node-http-proxy options is available](https://github.com/nodejitsu/node-http-proxy#options).

## Use Cases

RedWire is a perfect replacement for nginx to dispatch requests to NodeJs servers. Here are other use cases:

- **HTTP/SSL server** - use RedWire to expose insecure websites and APIs secure on the internet.
- **Authentication** - add authentication checks in front of your generated APIs.
- **Logging and Diagnostics** - all requests can be logged with simple middleware, use RedWire to diagnose web issues.
- **API Aggregation** - pull together many different APIs at different URLs into one uniform URL for your users. e.g. api.company.com or company.com/api.
- **Dynamic Load Balancing** - add and remove servers from your pool at runtime. Hook up etcd or consul and load balance automatically.

At MetOcean we're using RedWire in all these situations.

Are you using RedWire for something that isn't on this list? Let us know!


## TODO

- Tests for https
- Tests for ws
- Tests for removing dispatch nodes
