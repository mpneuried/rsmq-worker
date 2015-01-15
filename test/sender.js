(function() {
  var RSMQWorker, musicA, worker;

  RSMQWorker = require("../.");

  worker = new RSMQWorker("myqueue", {
    autostart: false
  });

  musicA = ["A4|.5", "A4|.5", "A4|.5", "F4|.3", "C5|.1", "A4|.5", "F4|.3", "C5|.1", "A4|1", "E5|.5", "E5|.5", "E5|.5", "F5|.3", "C5|.1", "GS4|.5", "F4|.3", "C5|.1", "A4|1", "end"];

  worker.on("ready", (function(_this) {
    return function() {
      var msg, _i, _len;
      for (_i = 0, _len = musicA.length; _i < _len; _i++) {
        msg = musicA[_i];
        console.log("SEND", msg);
        worker.send(msg);
      }
    };
  })(this));

}).call(this);
