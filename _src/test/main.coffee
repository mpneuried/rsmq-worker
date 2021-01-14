should = require( 'should' )
randomString = require( 'randoms/dist/str.js' )
randomNum = require( 'randoms/dist/num.js' )
async = require( 'async' )
randomNum.default()
_queuename = randomString.alphaNum( 10)
worker = null
_created = null

describe "----- rsmq-worker TESTS -----", ->

	before ( done )->

		RSMQWorker = require( "../." )
		worker = new RSMQWorker( _queuename, { interval: [ 0, 1, 5 ] } )
		_created = Math.round( Date.now() / 1000 )
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
		_tRecv = 0
		# Implement tests cases here
		it "check interval config", ( done )->
			worker.config.interval.length.should.equal( 3 )
			worker.config.interval[ 0 ].should.equal( 0 )
			worker.config.interval[ 1 ].should.equal( 1 )
			worker.config.interval[ 2 ].should.equal( 5 )
			done()
			return
		
		# Implement tests cases here
		it "first test", ( done )->
			_examplemsg = randomString.some(randomNum.default(4,99))
			
			_testFn = ( msg, next, id )->

				should.equal( msg, _examplemsg )
				next()
				
				worker.removeListener( "message", _testFn )
				done()
				return

			worker.on( "message", _testFn )

			
			worker.send( _examplemsg )
			_tRecv++
			return

		it "delay test", ( done )->
			_examplemsg = randomString.some(randomNum.default(4,99))
			_start = Date.now()
			_delay = 5
			@timeout( _delay*1.5*1000 )
			_testFn = ( msg, next, id )->

				should.equal( msg, _examplemsg )
				next()
				worker.removeListener( "message", _testFn )
				_diff = Math.round( ( Date.now() - _start )/1000 )
				_diff.should.be.above(_delay)
				done()
				return

			worker.on( "message", _testFn )
			
			worker.send( _examplemsg, _delay )
			_tRecv++
			return

		it "delay test with callback", ( done )->
			_examplemsg = randomString.some(randomNum.default(4,99))
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
			
			_tRecv++
			worker.send _examplemsg, _delay, ( err )->
				should.not.exist( err )
				return
			return
		
		it "test size method", ( done )->
			@timeout( 15000 )
			_COUNT = 10
			_examplemsgs = []
			for _x in [1.._COUNT]
				_examplemsgs.push randomString.some(randomNum.default(4,99))
			
			_runHiddenSize = ( next )->
				return ->
					# check hidden size and go on
					worker.size true, ( err, size )->
						throw err if err
						should.exist( size )
						size.should.be.a.number
						size.should.equal( 1 )
						_idx++
						next()
						worker.start()
						return
					return
			
			_idx = 0
			_testFn = ( msg, next, id )->
				should.equal( msg, _examplemsgs[ _idx ] )
				
				if _idx is 0
					# stop and wait to check the hidden size
					setTimeout( _runHiddenSize( next ), 1000 )
					worker.stop()
					return
				
				next()
				
				_idx++
				# done if all messages are received
				if _idx >= _COUNT
					worker.removeListener( "message", _testFn )
					done()
				return

			worker.on( "message", _testFn )

			worker.stop()
			
			_fnSend = ( msg, cba )->
				_tRecv++
				worker.send( msg, 0, cba )
				return
				
			async.every _examplemsgs, _fnSend, ( err )->
				throw err if err
						
				worker.size ( err, size )->
					worker.start() # start immediate so the following tests will not fail due to a stopped worker
					
					throw err if err
					should.exist( size )
					size.should.be.a.number
					size.should.equal( _COUNT )
					
					return
				return
			return
			
		it "test info method", ( done )->
			@timeout( 15000 )
			_COUNT = 10
			_examplemsgs = []
			for _x in [1.._COUNT]
				_examplemsgs.push randomString.some(randomNum.default(4,99))
					
			_idx = 0
			_testFn = ( msg, next, id )->
				should.equal( msg, _examplemsgs[ _idx ] )
				
				next()
				
				_idx++
				# done if all messages are received
				if _idx >= _COUNT
					worker.removeListener( "message", _testFn )
					done()
				return

			worker.on( "message", _testFn )

			worker.stop()
			
			_fnSend = ( msg, cba )->
				_tRecv++
				worker.send( msg, 0, cba )
				return
				
			async.every _examplemsgs, _fnSend, ( err )->
				throw err if err
						
				worker.info ( err, info )->
					worker.start() # start immediate so the following tests will not fail due to a stopped worker
					
					throw err if err
					should.exist( info )
					info.should.have.property( "msgs" )
						.with.equal( _COUNT )
						
					info.should.have.property( "delay" )
						.with.equal( 0 )
						
					info.should.have.property( "vt" )
						.with.equal( 30 )
						
					info.should.have.property( "maxsize" )
						.with.equal( 65536 )
					
					info.should.have.property( "totalsent" )
						.with.equal( _tRecv )
						
					info.should.have.property( "totalrecv" )
						.with.equal( _tRecv - _COUNT )
					
					info.should.have.property( "created" )
						.with.approximately( _created, 10 )
						
					info.should.have.property( "modified" )
						.with.approximately( _created, 10 )
					
						
					
					return
				return
			return
		
		it "error throw within message processing - Issue #3 (A)", ( done )->
			_examplemsg = randomString.some(randomNum.default(4,99))
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
			_examplemsg = randomString.some(randomNum.default(4,99))
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
		
		_examplemsg2 = randomString.some(randomNum.default(4,99))
		it "test stop method - Pull #5 stop", ( done )->
			_examplemsg = randomString.some(randomNum.default(4,99))
			@timeout( 6000 )
			
			idx = 0
			_testFn = ( msg, next, id )->
				idx++
				if idx <= 1
					should.equal( msg, _examplemsg )
					worker.stop()
					worker.send _examplemsg2, 0, ( err )->
						should.not.exist( err )
						return
					next()
					return
				throw new Error( "Got second message" )
				done()
				return
				
			_endFn = ( err, rawmsg )->
				worker.removeListener( "message", _testFn )
				done()
				return

			
			worker.on( "message", _testFn )
			
			worker.send _examplemsg, 0, ( err )->
				should.not.exist( err )
				return
				
			setTimeout( _endFn, 5000 )
			return
		
		it "test stop method - Pull #5 start", ( done )->
			_testFn = ( msg, next, id )->
				should.equal( msg, _examplemsg2 )
				done()
				return
			
			worker.on( "message", _testFn )
			worker.start()
			return
		return
	return
