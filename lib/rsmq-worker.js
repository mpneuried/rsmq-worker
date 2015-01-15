(function() {
  var RSMQ, rsmqWorker, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  _ = require("lodash");

  RSMQ = require("rsmq");

  rsmqWorker = (function(_super) {
    __extends(rsmqWorker, _super);

    rsmqWorker.prototype.defaults = function() {
      return this.extend(rsmqWorker.__super__.defaults.apply(this, arguments), {
        intervall: [0, 1, 5, 10],
        maxReceiveCount: 10,
        autostart: false,
        rsmq: null,
        redis: null,
        redisPrefix: "",
        host: "localhost",
        port: 6379,
        options: {}
      });
    };


    /*	
    	 *# constructor
     */

    function rsmqWorker(queuename, options) {
      this.queuename = queuename;
      this.stop = __bind(this.stop, this);
      this.next = __bind(this.next, this);
      this.intervall = __bind(this.intervall, this);
      this.check = __bind(this.check, this);
      this.del = __bind(this.del, this);
      this.receive = __bind(this.receive, this);
      this._runOfflineMessages = __bind(this._runOfflineMessages, this);
      this._send = __bind(this._send, this);
      this.send = __bind(this.send, this);
      this.start = __bind(this.start, this);
      this._initQueue = __bind(this._initQueue, this);
      this._getRsmq = __bind(this._getRsmq, this);
      this._initRSMQ = __bind(this._initRSMQ, this);
      this.defaults = __bind(this.defaults, this);
      rsmqWorker.__super__.constructor.call(this, options);
      this.ready = false;
      this.waitCount = 0;
      this.on("next", this.next);
      this.on("data", this.check);
      this.offlineQueue = [];
      this._initRSMQ();
      if (this.config.autostart) {
        this.on("ready", this.start);
      }
      this.debug("config", this.config);
      return;
    }


    /*
    	 *# _initRSMQ
    	
    	`rsmq-worker._initRSMQ()`
    	
    	Initialize rsmq	and handle disconnects
    	
    	@api private
     */

    rsmqWorker.prototype._initRSMQ = function() {
      this.queue = this._getRsmq();
      this.reconnectActive = false;
      this.queue.on("disconnect", (function(_this) {
        return function(err) {
          var _intervall;
          _this.warning("redis connection lost");
          _intervall = _this.timeout != null;
          if (!_this.reconnectActive) {
            _this.reconnectActive = true;
            if (_intervall) {
              _this.stop();
            }
            _this.queue.once("connect", function() {
              _this.waitCount = 0;
              _this.reconnectActive = false;
              _this.queue = new _this._getRsmq(true);
              _this._runOfflineMessages();
              if (_intervall) {
                _this.intervall();
              }
              _this.warning("redis connection reconnected");
            });
          }
        };
      })(this));
      if (this.queue.connected) {
        this._initQueue();
      } else {
        this.queue.once("connect", this._initQueue);
      }
    };


    /*
    	 *# _getRsmq
    	
    	`rsmq-worker._getRsmq( [forceInit] )`
    	
    	get or init the rsmq instance
    	
    	@param { Boolean } [forceInit=false] init rsmq even if it has been allready inited
    	
    	@return { RedisSMQ } A rsmq instance 
    	
    	@api private
     */

    rsmqWorker.prototype._getRsmq = function(forceInit) {
      var _ref, _ref1, _ref2, _ref3;
      if (forceInit == null) {
        forceInit = false;
      }
      if (!forceInit && (this.queue != null)) {
        return this.queue;
      }
      if (((_ref = this.config.rsmq) != null ? (_ref1 = _ref.constructor) != null ? _ref1.name : void 0 : void 0) === "RedisSMQ") {
        this.debug("use given rsmq client");
        return this.config.rsmq;
      }
      if (((_ref2 = this.config.redis) != null ? (_ref3 = _ref2.constructor) != null ? _ref3.name : void 0 : void 0) === "RedisClient") {
        return new RSMQ({
          client: this.config.redis,
          ns: this.config.redisPrefix
        });
      } else {
        return new RSMQ({
          host: this.config.host,
          port: this.config.port,
          options: this.config.options,
          ns: this.config.redisPrefix
        });
      }
    };


    /*
    	 *# _initQueue
    	
    	`rsmq-worker._initQueue()`
    	
    	check if the given queue exists
    	
    	@api private
     */

    rsmqWorker.prototype._initQueue = function() {
      this.queue.createQueue({
        qname: this.queuename
      }, (function(_this) {
        return function(err, resp) {
          if ((err != null ? err.name : void 0) === "queueExists") {
            _this.emit("ready");
            return;
          }
          if (err) {
            throw err;
          }
          if (resp === 1) {
            _this.debug("queue created");
          } else {
            _this.debug("queue allready existed");
          }
          _this.ready = true;
          _this.emit("ready");
        };
      })(this));
    };


    /*
    	 *# start
    	
    	`rsmq-worker.start()`
    	
    	Start the worker
    	
    	@api public
     */

    rsmqWorker.prototype.start = function() {
      if (this.ready) {
        this.intervall();
        return;
      }
      this.on("ready", this.intervall);
      return this;
    };

    rsmqWorker.prototype.send = function(msg, delay) {
      if (delay == null) {
        delay = 0;
      }
      if (this.queue.connected) {
        this._send(msg, delay);
      } else {
        this.debug("store message during redis offline time", msg, delay);
        this.offlineQueue.push({
          msg: msg,
          delay: delay
        });
      }
      return this;
    };

    rsmqWorker.prototype._send = function(msg, delay) {
      this.queue.sendMessage({
        qname: this.queuename,
        message: msg,
        delay: delay
      }, (function(_this) {
        return function(err, resp) {
          if (err) {
            _this.error("send pending queue message", err);
            return;
          }
          _this.emit("new", resp);
        };
      })(this));
    };

    rsmqWorker.prototype._runOfflineMessages = function() {
      var sndData, _aq, _i, _len, _ref;
      if (this.offlineQueue.length) {
        _aq = async.queue((function(_this) {
          return function(sndData, cb) {
            _this.debug("run offline stored message", arguments);
            _this._send(sndData.msg, sndData.delay);
            cb();
          };
        })(this), 3);
        _ref = this.offlineQueue;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          sndData = _ref[_i];
          this.debug("queue offline stored message", sndData);
          _aq.push(sndData);
        }
      }
    };

    rsmqWorker.prototype.receive = function(_useIntervall) {
      if (_useIntervall == null) {
        _useIntervall = false;
      }
      this.debug("start receive");
      this.queue.receiveMessage({
        qname: this.queuename
      }, (function(_this) {
        return function(err, msg) {
          var _fnNext, _id;
          _this.debug("received", msg);
          if (err) {
            if (_useIntervall) {
              _this.emit("next", true);
            }
            _this.error("receive queue message", err);
            return;
          }
          if (msg != null ? msg.id : void 0) {
            _this.emit("data", msg);
            _id = msg.id;
            _fnNext = function(err, del) {
              if (del == null) {
                del = true;
              }
              if (del) {
                _this.del(_id);
              }
              if (_useIntervall) {
                _this.emit("next");
              }
            };
            _this.emit("message", msg.message, _fnNext, _id);
          } else {
            if (_useIntervall) {
              _this.emit("next", true);
            }
          }
        };
      })(this));
    };

    rsmqWorker.prototype.del = function(id) {
      this.queue.deleteMessage({
        qname: this.queuename,
        id: id
      }, (function(_this) {
        return function(err, resp) {
          if (err) {
            _this.error("delete queue message", err);
            return;
          }
          _this.debug("delete queue message", resp);
          _this.emit("deleted", id);
        };
      })(this));
      return this;
    };

    rsmqWorker.prototype.check = function(msg) {
      if (msg.rc >= this.config.maxReceiveCount) {
        this.emit("exceeded", msg.message, msg.rc);
        this.warning("message received more than " + this.config.maxReceiveCount + " times. So delete it", msg);
        this.del(msg.id);
      }
    };

    rsmqWorker.prototype.intervall = function() {
      this.debug("run intervall");
      this.receive(true);
    };

    rsmqWorker.prototype.next = function(wait) {
      var _timeout;
      if (wait == null) {
        wait = false;
      }
      if (!wait) {
        this.waitCount = 0;
      }
      if (_.isArray(this.config.intervall)) {
        _timeout = this.config.intervall[this.waitCount] != null ? this.config.intervall[this.waitCount] : _.last(this.config.intervall);
      } else {
        if (wait) {
          _timeout = this.config.intervall;
        } else {
          _timeout = 0;
        }
      }
      this.debug("wait", this.waitCount, _timeout * 1000);
      if (_timeout >= 0) {
        if (this.timeout != null) {
          clearTimeout(this.timeout);
        }
        this.timeout = _.delay(this.intervall, _timeout * 1000);
        this.waitCount++;
      } else {
        this.intervall();
      }
    };

    rsmqWorker.prototype.stop = function() {
      if (this.timeout != null) {
        clearTimeout(this.timeout);
      }
      return this;
    };

    return rsmqWorker;

  })(require("mpbasic")());

  module.exports = rsmqWorker;

}).call(this);
