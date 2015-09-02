RSMQWorker = require( "../." )
worker = new RSMQWorker( "myqueue", autostart: false )

worker.on "ready", ->
	for msg in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split( "" )
		console.log( "SEND", msg )
		worker.send( msg )
	return
