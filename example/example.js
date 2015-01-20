(function() {
  var RSMQWorker, worker;

  RSMQWorker = require("../.");

  worker = new RSMQWorker("myqueue", {
    interval: [0, 1, 2, 3]
  });

  worker.on("message", (function(_this) {
    return function(msg, next, id) {
      console.log("RECEIVED", msg);
      next();
    };
  })(this));

  worker.start();

}).call(this);
