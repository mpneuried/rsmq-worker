RW = require( "../." )
worker = new RW( "stoptest" )

worker.on "error", ( err )->
	console.log "ERR", err
	return

worker.on "message", ( msg, next, id )->
	console.log "MSG", msg, id
	next()
	console.log "stop?"
	setTimeout( worker.quit, 500 )
	return
	
worker.start()
worker.send( "TEST!" )
