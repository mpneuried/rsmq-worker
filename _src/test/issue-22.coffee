RSMQWorker = require( "../../." )

queueName = "test-rsmq-worker-22"
timeToProcessMessage = 60

worker = new RSMQWorker( queueName, {
	timeout: timeToProcessMessage * 1000
	invisibletime: 0
})

_date = ->
	return new Date().toString()[16..23] + " : "

worker.on "timeout", ( msg )->
	console.log( _date() + "TIMEOUT", msg.id, msg.rc )
	return
worker.on "exceeded", ( msg )->
	console.log( _date() + "EXCEEDED", msg.id, msg.rc )
	return
worker.on "error", ( msg )->
	console.log( _date() + "ERROR", msg.id, msg.rc )
	return

worker.on "message", ( msg, next )->
	
	_n = ->
		console.log _date() + "DONE: " + msg
		next()
		return
	
	# long running process
	console.log _date() + "PROCESS: " + msg
	
	switch msg
		when "fast"
			worker.send( "slow" )
			_n()
		when "slow"
			worker.send( "timeout" )
			setTimeout( _n, Math.round( timeToProcessMessage / 0.7 ) * 1000 )
		when "timeout"
			worker.send( "exit" )
			setTimeout( _n, Math.round( timeToProcessMessage / 1.3 ) * 1000 )
		when "exit"
			_n()
			worker.quit()
			setTimeout( process.exit, 500 )
	return


if worker.ready
	console.log _date() + "READY"
	worker.send( "fast" )
else
	worker.on "ready", ->
		console.log _date() + "READY"
		worker.send( "fast" )
		return
	
worker.start()
