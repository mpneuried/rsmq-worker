(function() {
  var Module, should, _moduleInst;

  should = require('should');

  Module = require("../.");

  _moduleInst = null;

  describe("----- rsmq-worker TESTS -----", function() {
    before(function(done) {
      _moduleInst = new Module();
      done();
    });
    after(function(done) {
      done();
    });
    describe('Main Tests', function() {
      it("first test", function(done) {
        done();
      });
    });
  });

}).call(this);
