RSMQWorker = require( "../." )
worker = new RSMQWorker( "myqueue", { intervall: [ 0, 1, 2, 3 ] } )

worker.on "message", ( msg, next, id )=>
	console.log( "RECEIVED", msg )
	next()
	return

worker.start()