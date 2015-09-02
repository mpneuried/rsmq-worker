RSMQWorker = require( "../." )
worker = new RSMQWorker( "myqueue", { interval: [ 0, 1, 2, 3 ] } )

worker.on "message", ( msg, next, id )->
	console.log( "RECEIVED", msg )
	next()
	return

worker.start()
