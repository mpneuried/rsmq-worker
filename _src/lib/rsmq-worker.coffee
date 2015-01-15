# # rsmqWorker

# ### extends [NPM:MPBasic](https://cdn.rawgit.com/mpneuried/mpbaisc/master/_docs/index.coffee.html)

#
# ### Exports: *Class*
#
# Main Module to init the heartbeat to redis
# 

# **node modules**
_ = require("lodash")
RSMQ = require("rsmq")

class rsmqWorker extends require( "mpbasic" )()

	# ## defaults
	defaults: =>
		return @extend super,
			# **rsmqWorker.intervall** *Number[]* An Array of increasing wait times in seconds
			intervall: [ 0, 1, 5, 10 ]
			# **rsmqWorker.maxReceiveCount** *Number* Receive count until a message will be exceeded
			maxReceiveCount: 10
			# **rsmqWorker.autostart** *Boolean* Autostart the worker on init
			autostart: false
			
			# **rsmqWorker.rsmq** *RedisSMQ* A allready existing rsmq instance to use instead of creating a new client
			rsmq: null

			# **rsmqWorker.redis** *RedisClient* A allready existing redis client instance to use if no `rsmq` instance has been defiend 
			redis: null
			# **rsmqWorker.redisPrefix** *String* The redis Prefix for rsmq if  no `rsmq` instance has been defiend 
			redisPrefix: ""
			
			# **rsmqWorker.host** *String* Host to connect to redis if no `rsmq` or `redis` instance has been defiend 
			host: "localhost"
			# **rsmqWorker.host** *Number* Port to connect to redis if no `rsmq` or `redis` instance has been defiend 
			port: 6379
			# **rsmqWorker.options** *Object* Options to connect to redis if no `rsmq` or `redis` instance has been defiend 
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
	## _initRSMQ
	
	`rsmq-worker._initRSMQ()`
	
	Initialize rsmq	and handle disconnects
	
	@api private
	###
	_initRSMQ: =>
		@queue = @_getRsmq()

		@reconnectActive = false

		# handle redis disconnect
		@queue.on "disconnect", ( err )=>
			@warning "redis connection lost"
			_intervall = @timeout?
			if not @reconnectActive
				@reconnectActive = true
				@stop() if _intervall

				# on reconnect
				@queue.once "connect", =>
					@waitCount = 0
					@reconnectActive = false
					@queue = new @_getRsmq( true )
					@_runOfflineMessages()
					@intervall() if _intervall
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
	
	`rsmq-worker._getRsmq( [forceInit] )`
	
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
	
	`rsmq-worker._initQueue()`
	
	check if the given queue exists
	
	@api private
	###
	_initQueue: =>
		@queue.createQueue qname: @queuename, ( err, resp )=>
			if err?.name is "queueExists"
				@emit "ready"
				return

			throw err if err

			if resp is 1
				@debug "queue created"
			else
				@debug "queue allready existed"

			@ready = true
			@emit "ready"
			return
		return

	###
	## start
	
	`rsmq-worker.start()`
	
	Start the worker
	
	@api public
	###
	start: =>
		if @ready
			@intervall()
			return
		@on "ready", @intervall
		return


	send: ( msg, delay = 0 )=>
		if @queue.connected
			@_send( msg, delay )
		else
			@debug "store message during redis offline time", msg, delay
			@offlineQueue.push( msg: msg, delay: delay )
		return

	_send: ( msg, delay )=>
		@queue.sendMessage { qname: @queuename, message: msg, delay: delay }, ( err, resp )=>
			if err
				@error "send pending queue message", err
				return
			@emit "new", resp
			return
		return

	_runOfflineMessages: =>
		if @offlineQueue.length
			_aq = async.queue( ( sndData, cb )=>
				@debug "run offline stored message", arguments
				@_send( sndData.msg, sndData.delay )
				cb()
				return
			, 3 )
			for sndData in @offlineQueue
				@debug "queue offline stored message", sndData
				_aq.push sndData
		return

	receive: ( _useIntervall = false )=>
		@debug "start receive"
		@queue.receiveMessage qname: @queuename, ( err, msg )=>
			@debug "received", msg
			if err
				@emit( "next", true ) if _useIntervall
				@error "receive queue message", err
				return

			if msg?.id
				@emit "data", msg
				_id = msg.id
				_fnNext = ( err, del = true )=>
					@del( _id ) if del
					@emit( "next" ) if _useIntervall
					return
				@emit "message", msg.message, _fnNext, _id
			else
				@emit( "next", true ) if _useIntervall
			return
		return

	del: ( id )=>
		@queue.deleteMessage qname: @queuename, id: id, ( err, resp )=>
			if err
				@error "delete queue message", err
				return
			@debug "delete queue message", resp
			@emit( "deleted", id )
			return
		return

	check: ( msg )=>
		if msg.rc >= @config.maxReceiveCount
			@emit "exceeded", msg.message, msg.rc
			@warning "message received more than #{@config.maxReceiveCount} times. So delete it", msg
			@del( msg.id )
		return

	intervall: =>
		@debug "run intervall"
		@receive( true )
		return

	next: ( wait = false )=>
		if not wait
			@waitCount = 0

		if _.isArray( @config.intervall )
			_timeout = if @config.intervall[ @waitCount ]? then @config.intervall[ @waitCount ] else _.last( @config.intervall )
		else
			if wait
				_timeout = @config.intervall
			else
				_timeout = 0
		
		@debug "wait", @waitCount, _timeout * 1000
		if _timeout >= 0
			clearTimeout( @timeout ) if @timeout?
			@timeout = _.delay( @intervall, _timeout * 1000 )
			@waitCount++
		else
			@intervall()
		return

	stop: =>
		clearTimeout( @timeout ) if @timeout?
		return

#export this class
module.exports = rsmqWorker