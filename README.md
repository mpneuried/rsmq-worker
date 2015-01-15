rsmq-worker
============

[![Build Status](https://secure.travis-ci.org/mpneuried/rsmq-worker.png?branch=master)](http://travis-ci.org/mpneuried/rsmq-worker)
[![Build Status](https://david-dm.org/mpneuried/rsmq-worker.png)](https://david-dm.org/mpneuried/rsmq-worker)
[![NPM version](https://badge.fury.io/js/rsmq-worker.png)](http://badge.fury.io/js/rsmq-worker)

RSMQ helper to simply implement a worker around the message queue.

## Install

```
  npm install rsmq-worker
```

## Initialize

```
  new RSMQWorker( queuename, options );

```

**Config** 

- **queuename**: *( `String` required )* The queuename to pull the messages
- **options** *( `Object` optional )* The configuration object
	- **options.intervall**: *( `Number[]` optional; default = `[ 0, 1, 5, 10 ]` )* An Array of increasing wait times in seconds
	- **options.maxReceiveCount**: *( `Number` optional; default = `10` )* Receive count until a message will be exceeded
	- **options.autostart**: *( `Boolean` optional; default = `false` )* Autostart the worker on init
	- **options.rsmq**: *( `RedisSMQ` optional; default = `null` )* A allready existing rsmq instance to use instead of creating a new client
	- **options.redis**: *( `RedisClient` optional; default = `null` )* A allready existing redis client instance to use if no `rsmq` instance has been defiend 
	- **options.redisPrefix**: *( `String` optional; default = `""` )* The redis Prefix for rsmq if  no `rsmq` instance has been defiend 
	- **options.host**: *( `String` optional; default = `"localhost"` )* Host to connect to redis if no `rsmq` or `redis` instance has been defiend 
	- **options.host**: *( `Number` optional; default = `6379` )* Port to connect to redis if no `rsmq` or `redis` instance has been defiend 
	- **options.options**: *( `Object` optional; default = `{}` )* Options to connect to redis if no `rsmq` or `redis` instance has been defiend 

**Example:**

```
  var RSMQWorker = require( "rsmq-worker" );
  var worker = new RSMQWorker( "myqueue" );

  worker.on( "message", function( msg, next, id ){
  	// process your message
  	next()
  });

  worker.start();
```

## Methods

### `.start()`

If you haven't defined the config `autostart` to `true` you have to call the `.start()` method.

**Return**

*( Self )*: The instance itself for chaining.

### `.del( id )`

Helper function to simply delete a message after it has been processed.

**Arguments**

* `id` : *( `String` required )*: The rsmq message id.

**Return**

*( Self )*: The instance itself for chaining.

### `.stop()`

Stop the receive interval.

**Return**

*( Self )*: The instance itself for chaining.

### `.send( msg [, delay ] )`

Helper function to simply send a message in the configured queue.

**Arguments**

* `filename` : *( `String` required )*: The rsmq message. In best practice it's a stringified JSON with additional data.
* `delay` : *( `Number` optional; default = `0` )*: The message delay to hide this message for the next `x` seconds.

**Return**

*( Self )*: The instance itself for chaining.

## Events

### `message`

### `ready`

### `data`

### `deleted`

### `exceeded`

## Todos/Ideas

> Currently no feature ideas

## Release History
|Version|Date|Description|
|:--:|:--:|:--|
|0.0.1|2015-1-14|Initial commit|

## The MIT License (MIT)

Copyright © 2013 Mathias Peter, http://www.tcs.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
