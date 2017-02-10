spawn = require('child_process').spawn

PORT = process.env.PORT or 6379

rand = require( 'randoms' )
RW = require( "../." )
worker = new RW( "pingpong", { port: PORT, interval: [ 0, 0.1 ] } )

redis_server = null
startRedis = ->
	redis_server = spawn('redis-server', ['--port', PORT])
	setTimeout( killRedis, rand.number( 2000, 8000 ))
	return
	
killRedis = ->
	if redis_server?
		redis_server.kill()
		
	setTimeout( ->
		redis_server = null
	, 0 )
	setTimeout( startRedis, rand.number( 2000, 8000 ))
	return

ping = ->
	worker.send "ping", ( err )->
		if err
			console.error( err )
			return
		
		process.stdout.write("Ping ... ")
		return
	return
	
worker.on "error", ( err )->
	console.log "ERR", err
	return

worker.on "message", ( msg, next, id )->
	process.stdout.write("Pong\n")
	next()
	ping()
	return
	
worker.queue.on "disconnect", ->
	console.log "disconnect"
	return

worker.queue.on "connect", ->
	console.log "connect"
	return

startRedis()

worker.start()

ping()
