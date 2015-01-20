(function() {
  var RSMQWorker, worker;

  RSMQWorker = require("../.");

  worker = new RSMQWorker("myqueue", {
    autostart: false
  });

  worker.on("ready", (function(_this) {
    return function() {
      var msg, _i, _len, _ref;
      _ref = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        msg = _ref[_i];
        console.log("SEND", msg);
        worker.send(msg);
      }
    };
  })(this));

}).call(this);
