should = require( 'should' )
utils = require( './utils' )

_queuename = utils.randomString( 10, 1 )
worker = null

describe "----- rsmq-worker TESTS -----", ->

	before ( done )->

		RSMQWorker = require( "../." )
		worker = new RSMQWorker( _queuename, { interval: [ 0, 1 ] } )

		worker.on "ready", =>
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
			
			_testFn = ( msg, next, id )=>

				should.equal( msg, _examplemsg )
				next()
				
				worker.removeListener( "message", _testFn )
				done()
				return

			worker.on( "message", _testFn )
			
			worker.send( _examplemsg )
			return

		return
	return