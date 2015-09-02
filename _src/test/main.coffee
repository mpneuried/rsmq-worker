should = require( 'should' )
utils = require( './utils' )

_queuename = utils.randomString( 10, 1 )
worker = null

describe "----- rsmq-worker TESTS -----", ->

	before ( done )->

		RSMQWorker = require( "../." )
		worker = new RSMQWorker( _queuename, { interval: [ 0, 1 ] } )

		worker.on "ready", ->
			done()
			return

		worker.start()

		return

	after ( done )->
		#  TODO teardown
		done()
		return

	describe 'Main Tests', ->

		# Implement tests cases here
		it "first test", ( done )->
			_examplemsg = utils.randomString( utils.randRange( 4, 99 ), 3 )
			
			_testFn = ( msg, next, id )->

				should.equal( msg, _examplemsg )
				next()
				
				worker.removeListener( "message", _testFn )
				done()
				return

			worker.on( "message", _testFn )

			
			worker.send( _examplemsg )
			return

		it "delay test", ( done )->
			_examplemsg = utils.randomString( utils.randRange( 4, 99 ), 3 )
			_start = Date.now()
			_delay = 5
			@timeout( _delay*1.5*1000 )
			_testFn = ( msg, next, id )->

				should.equal( msg, _examplemsg )
				next()
				_diff = Math.round( ( Date.now() - _start )/1000 )
				_diff.should.be.above(_delay)
				worker.removeListener( "message", _testFn )
				done()
				return

			worker.on( "message", _testFn )
			
			worker.send( _examplemsg, _delay )
			return

		it "delay test with callback", ( done )->
			_examplemsg = utils.randomString( utils.randRange( 4, 99 ), 3 )
			_start = Date.now()
			_delay = 5
			@timeout( _delay*1.5*1000 )
			_testFn = ( msg, next, id )->

				should.equal( msg, _examplemsg )
				next()
				_diff = Math.round( ( Date.now() - _start )/1000 )
				_diff.should.be.above(_delay)
				worker.removeListener( "message", _testFn )
				done()
				return

			worker.on( "message", _testFn )
			
			worker.send _examplemsg, _delay, ( err )->
				should.not.exist( err )
				return
			return
		
		it "error throw within message processing - Issue #3 (A)", ( done )->
			_examplemsg = utils.randomString( utils.randRange( 4, 99 ), 3 )
			_start = Date.now()
			@timeout( 3000 )
			
			_testFn = ( msg, next, id )->
				
				# force a code error
				throw new Error( "TESTERROR" )
				next()
				return
				
			_errorFn = ( err, rawmsg )->
				should.equal( err.message, "TESTERROR" )
				should.equal( rawmsg.message, _examplemsg )
				worker.removeListener( "message", _testFn )
				worker.removeListener( "error", _errorFn )
				done()
				return
				
			worker.on( "message", _testFn )
			
			worker.on( "error", _errorFn )
			
			worker.send _examplemsg, 0, ( err )->
				should.not.exist( err )
				return
			return
		
		it "code error within message processing - Issue #3 (B)", ( done )->
			_examplemsg = utils.randomString( utils.randRange( 4, 99 ), 3 )
			_start = Date.now()
			@timeout( 3000 )
			
			_testFn = ( msg, next, id )->
				
				# force a code error
				_x = msg.data.not.existing.path
				next()
				return
				
			_errorFn = ( err, rawmsg )->
				should.equal( err.name, "TypeError" )
				should.equal( rawmsg.message, _examplemsg )
				worker.removeListener( "message", _testFn )
				worker.removeListener( "error", _errorFn )
				worker.config.alwaysLogErrors = false
				done()
				return
			
			# set this config flag to test if the error will be logged to the console even with attached error handler
			worker.config.alwaysLogErrors = true
			
			worker.on( "message", _testFn )
			
			worker.on( "error", _errorFn )
			
			worker.send _examplemsg, 0, ( err )->
				should.not.exist( err )
				return
			return

		return
	return
