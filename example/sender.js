(function() {
  var RSMQWorker, worker;

  RSMQWorker = require("../.");

  worker = new RSMQWorker("myqueue", {
    autostart: false
  });

  worker.on("ready", (function(_this) {
    return function() {
      var i, len, msg, ref;
      ref = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
      for (i = 0, len = ref.length; i < len; i++) {
        msg = ref[i];
        console.log("SEND", msg);
        worker.send(msg);
      }
    };
  })(this));

}).call(this);
