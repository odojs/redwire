// Generated by CoffeeScript 1.8.0
var LoadBalancer,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

module.exports = LoadBalancer = (function() {
  function LoadBalancer(options) {
    this.distribute = __bind(this.distribute, this);
    this.next = __bind(this.next, this);
    this.remove = __bind(this.remove, this);
    this.add = __bind(this.add, this);
    this._options = {
      method: 'roundrobin'
    };
    if ((options != null ? options.method : void 0) != null) {
      this._options.method = options.method;
    }
    this._servers = [];
    this._index = 0;
  }

  LoadBalancer.prototype.add = function(target) {
    if (target.indexOf('http://') !== 0 && target.indexOf('https://') !== 0) {
      target = "http://" + target;
    }
    this._servers.push(target);
    return this;
  };

  LoadBalancer.prototype.remove = function(target) {
    if (target.indexOf('http://') !== 0 && target.indexOf('https://') !== 0) {
      target = "http://" + target;
    }
    this._servers.remove(target);
    return this;
  };

  LoadBalancer.prototype.next = function() {
    var result;
    this._index = this._index % this._servers.length;
    result = this._servers[this._index];
    this._index++;
    return result;
  };

  LoadBalancer.prototype.distribute = function() {
    return (function(_this) {
      return function(mount, url, req, res, next) {
        req.target = _this.next();
        return next();
      };
    })(this);
  };

  return LoadBalancer;

})();
