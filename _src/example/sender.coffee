RSMQWorker = require( "../." )
worker = new RSMQWorker( "myqueue", autostart: false )

musicA = [
	"A4|.5"
	"A4|.5"
	"A4|.5"
	"F4|.3"
	"C5|.1"
	"A4|.5"
	"F4|.3"
	"C5|.1"
	"A4|1"
	"E5|.5"
	"E5|.5"
	"E5|.5"
	"F5|.3"
	"C5|.1"
	"GS4|.5"
	"F4|.3"
	"C5|.1"
	"A4|1"
	"end"
]

worker.on "ready", =>
	for msg in musicA
		console.log( "SEND", msg )
		worker.send( msg )
	return