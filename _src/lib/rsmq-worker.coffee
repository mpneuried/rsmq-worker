# # RSMQWorker

# ### extends [NPM:MPBasic](https://cdn.rawgit.com/mpneuried/mpbaisc/master/_docs/index.coffee.html)

#
# ### Exports: *Class*
#
# Main Module to init the heartbeat to redis
# 

# **node modules**
_ = require("lodash")
async = require("async")
RSMQ = require("rsmq")

class RSMQWorker extends require( "mpbasic" )()

	# ## defaults
	defaults: =>
		return @extend super,
			# **RSMQWorker.interval** *Number[]* An Array of increasing wait times in seconds
			interval: [ 0, 1, 5, 10 ]
			# **RSMQWorker.maxReceiveCount** *Number* Receive count until a message will be exceeded
			maxReceiveCount: 10
			# **RSMQWorker.invisibletime** *Number* A time in seconds to hide a message after it has been received.
			invisibletime: 30
			# **RSMQWorker.defaultDelay** *Number* The default delay in seconds for for sending new messages to the queue.
			defaultDelay: 1
			# **RSMQWorker.autostart** *Boolean* Autostart the worker on init
			autostart: false
			# **RSMQWorker.customExceedCheck** *Function* A custom function, with the message id and content as argument to build a custom exceed check
			customExceedCheck: null
			# **RSMQWorker.timeout** *Number* Message processing timeout in `ms`. If set to `0` it'll wait until infinity.
			timeout: 3000
			
			# **RSMQWorker.rsmq** *RedisSMQ* A allready existing rsmq instance to use instead of creating a new client
			rsmq: null

			# **RSMQWorker.redis** *RedisClient* A allready existing redis client instance to use if no `rsmq` instance has been defiend 
			redis: null
			# **RSMQWorker.redisPrefix** *String* The redis prefix/namespace for rsmq if no `rsmq` instance has been defined. This has th match the `ns` setting of RSMQ.
			redisPrefix: "rsmq"
			
			# **RSMQWorker.host** *String* Host to connect to redis if no `rsmq` or `redis` instance has been defiend 
			host: "localhost"
			# **RSMQWorker.host** *Number* Port to connect to redis if no `rsmq` or `redis` instance has been defiend 
			port: 6379
			# **RSMQWorker.options** *Object* Options to connect to redis if no `rsmq` or `redis` instance has been defiend 
			options: {}

	###	
	## constructor 
	###
	constructor: ( @queuename, options )->
		super( options )
		@ready = false

		@waitCount = 0
		@on "next", @next
		@on "data", @check

		@offlineQueue = []

		@_initRSMQ()

		# autostart worker on ready
		if @config.autostart
			@on "ready", @start 

		@debug "config", @config
		return 

	###
	## start
	
	`RSMQWorker.start()`
	
	Start the worker

	@return { RedisSMQ } A rsmq instance 

	@return { RSMQWorker } The instance itself for chaining. 

	@api public
	###
	start: =>
		if @ready
			@interval()
			return
		@on "ready", @interval
		return @

	###
	## stop
	
	`RSMQWorker.stop()`
	
	Stop the worker receiving messages
	
	@return { RSMQWorker } The instance itself for chaining. 
	
	@api public
	###
	stop: =>
		clearTimeout( @timeout ) if @timeout?
		return @

	###
	## send
	
	`RSMQWorker.send( msg [, delay] )`
	
	Helper/Convinience method to send a new message to the queue.
	
	@param { String } msg The message content 
	@param { Number } [delay=0] The message delay to hide this message for the next `x` seconds.
	@param { Function } [cb] A optional callback to get a secure response for a successful send.
	
	@return { RSMQWorker } The instance itself for chaining. 
	
	@api public
	###
	send: ( msg, args... )=>
		[ delay, cb ] = args
		if args.length > 1 and _.isFunction( delay )
			cb = delay
			delay = null

		if not delay?
			delay = @config.defaultDelay
		if @queue.connected
			@_send( msg, delay, cb )
		else
			@debug "store message during redis offline time", msg, delay
			@offlineQueue.push( msg: msg, delay: delay, cb: cb )
		return @

	###
	## del
	
	`RSMQWorker.del( id )`
	
	Delete a messge from queue. This is usually done automatically unless you call `next(false)`
	
	@param { String } id The rsmq message id 
	@param { Function } [cb] A optional callback to get a secure response for a successful delete.
	
	@return { RSMQWorker } The instance itself for chaining. 
	
	@api public
	###
	del: ( id, cb )=>
		@queue.deleteMessage qname: @queuename, id: id, ( err, resp )=>
			if err
				@error "delete queue message", err
				cb( err ) if _.isFunction( cb )
				return
			@debug "delete queue message", resp
			@emit( "deleted", id )
			cb( null ) if _.isFunction( cb )
			return
		return @

	###
	## changeInterval
	
	`RSMQWorker.changeInterval( interval )`
	
	Change the interval timeouts in operation
	
	@param { Number|Array } interval The new interval
	
	@return { RSMQWorker } The instance itself for chaining. 
	
	@api public
	###
	changeInterval: ( interval )=>
		@config.interval = interval
		return @

	###
	## _initRSMQ
	
	`RSMQWorker._initRSMQ()`
	
	Initialize rsmq	and handle disconnects
	
	@api private
	###
	_initRSMQ: =>
		@queue = @_getRsmq()

		@reconnectActive = false

		# handle redis disconnect
		@queue.on "disconnect", ( err )=>
			@warning "redis connection lost"
			_interval = @timeout?
			if not @reconnectActive
				@reconnectActive = true
				@stop() if _interval

				# on reconnect
				@queue.once "connect", =>
					@waitCount = 0
					@reconnectActive = false
					@queue = new @_getRsmq( true )
					@_runOfflineMessages()
					@interval() if _interval
					@warning "redis connection reconnected"
					return

			return
		if @queue.connected
			@_initQueue()
		else
			@queue.once "connect", @_initQueue
		
		return

	###
	## _getRsmq
	
	`RSMQWorker._getRsmq( [forceInit] )`
	
	get or init the rsmq instance
	
	@param { Boolean } [forceInit=false] init rsmq even if it has been allready inited
	
	@return { RedisSMQ } A rsmq instance 
	
	@api private
	###
	_getRsmq: ( forceInit = false )=>
		if not forceInit and @queue?
			return @queue

		if @config.rsmq?.constructor?.name is "RedisSMQ"
			@debug "use given rsmq client"
			return @config.rsmq
			

		if @config.redis?.constructor?.name is "RedisClient"
			return new RSMQ( client: @config.redis, ns: @config.redisPrefix )
		else
			return new RSMQ( host: @config.host, port: @config.port, options: @config.options, ns: @config.redisPrefix )

	###
	## _initQueue
	
	`RSMQWorker._initQueue()`
	
	check if the given queue exists
	
	@api private
	###
	_initQueue: =>
		@queue.createQueue qname: @queuename, ( err, resp )=>
			if err?.name is "queueExists"
				@ready = true
				@emit "ready"
				@_runOfflineMessages()
				return

			throw err if err

			if resp is 1
				@debug "queue created"
			else
				@debug "queue allready existed"

			@ready = true
			@emit "ready"

			# after the ready has been fired run saved messages
			@_runOfflineMessages()
			return
		return

	###
	## _send
	
	`RSMQWorker._send( msg, delay )`
	
	Internal send method that directly calls `rsmq.sendMessage()` .
	
	@param { String } msg The message content 
	@param { Number } delay The message delay to hide this message for the next `x` seconds.
	@param { Function } [cb] A optional callback function
	
	@api private
	###
	_send: ( msg, delay, cb )=>
		@queue.sendMessage { qname: @queuename, message: msg, delay: delay }, ( err, resp )=>
			if err
				@error "send pending queue message", err
				cb( err ) if cb? and _.isFunction( cb )
				return
			@emit "new", resp
			cb( null, resp ) if cb? and _.isFunction( cb )
			return
		return

	###
	## _runOfflineMessages
	
	`RSMQWorker._runOfflineMessages()`
	
	Runn all messages collected by `.send()` while redis has been offline 
	
	@api private
	###
	_runOfflineMessages: =>
		if @offlineQueue.length
			_aq = async.queue( ( sndData, cb )=>
				@debug "run offline stored message", arguments
				@_send( sndData.msg, sndData.delay, sndData.cb )
				cb()
				return
			, 3 )
			for sndData in @offlineQueue
				@debug "queue offline stored message", sndData
				_aq.push sndData
		return

	###
	## receive
	
	`RSMQWorker.receive( _useInterval )`
	
	Receive a message
	
	@param { Boolean } _us Fire a `next` event to call e new receive on the call of `next()` 
	
	@api private
	###
	receive: ( _useInterval = false )=>
		@debug "start receive"
		@queue.receiveMessage { qname: @queuename, vt: @config.invisibletime }, ( err, msg )=>
			@debug "received", msg
			if err
				@emit( "next", true ) if _useInterval
				@error "receive queue message", err
				return

			if msg?.id
				@emit "data", msg
				_id = msg.id#

				# add a processing timeout
				if @config.timeout > 0
					timeout = setTimeout( =>
						@warning "timeout", msg
						@emit "timeout", msg
						_fnNext( false )
						return
					, @config.timeout )

				_fnNext = _.once ( del = true )=>
					if _.isBoolean( del ) or _.isNumber( del )
						@del( _id ) if del
					else if del?
						# if there is a return value ant it's not a boolean or number i asume it's an error
						@emit "error", del, msg

					clearTimeout( timeout ) if timeout?
					@emit( "next" ) if _useInterval
					return
				try
					@emit "message", msg.message, _fnNext, _id
				catch _err
					@error "error", _err
					@emit "error", _err, msg
					_fnNext( false )
					return
			else
				@emit( "next", true ) if _useInterval
			return
		return

	###
	## check
	
	`RSMQWorker.check( msg )`
	
	Check if a message has been received to often and has to be deleted
	
	@param { Object } msg The raw rsmq message 
	
	@api private
	###
	check: ( msg )=>
		if @config.customExceedCheck?( msg )
			return

		if msg.rc >= @config.maxReceiveCount
			@emit "exceeded", msg
			@warning "message received more than #{@config.maxReceiveCount} times. So delete it", msg
			@del( msg.id )
		return

	###
	## interval
	
	`RSMQWorker.interval()`
	
	call receive the intervall
	
	@api private
	###
	interval: =>
		@debug "run interval"
		@receive( true )
		return

	###
	## next
	
	`RSMQWorker.next( [wait] )`
	
	Call the next recieve or wait until the next recieve has to be called
	
	@param { Boolean } [wait=false] Tell the next call that the last receive was empty to increase the wait time 
	
	@api private
	###
	next: ( wait = false )=>
		if not wait
			@waitCount = 0

		if _.isArray( @config.interval )
			_timeout = if @config.interval[ @waitCount ]? then @config.interval[ @waitCount ] else _.last( @config.interval )
		else
			if wait
				_timeout = @config.interval
			else
				_timeout = 0
		
		@debug "wait", @waitCount, _timeout * 1000
		if _timeout >= 0
			clearTimeout( @timeout ) if @timeout?
			@timeout = _.delay( @interval, _timeout * 1000 )
			@waitCount++
		else
			@interval()
		return



#export this class
module.exports = RSMQWorker