var fs = require( "fs" );
var RSMQWorker = require( "./." );

var fnCheck = function( msg ){
	// check function to not exceed the message if the content is `createmessages`
	if( msg.message === "createmessages" ){
		return true
	}
	return false
}

var worker = new RSMQWorker( "myqueue", {
	interval: [ .1, 1 ],				// wait 100ms between every receive and step up to 1,3 on empty receives
	invisibletime: 2,						// hide received message for 5 sec
	maxReceiveCount: 2,					// only receive a message 2 times until delete
	autostart: true,						// start worker on init
	customExceedCheck: fnCheck	// set the custom exceed check
});

//
worker.on( "message", function( message, next, id ){
	console.log( "message", message )
	if( message === "createmessages" ){
		next( false )
		worker.send( JSON.stringify( { type: "writefile", filename: "./test.txt", txt: "Foo Bar" } ) );
		worker.send( JSON.stringify( { type: "deletefile", filename: "./test.txt" } ) );
		return	
	}

	var _data = JSON.parse( message )
	switch( _data.type ){
		case "writefile": 
			fs.writeFile( _data.filename, _data.txt, function( err ){
				if( err ){
					console.error( err )
				}else{
					next()
				}
			});
			break;
		case "deletefile": 
			fs.unlink( _data.filename, function( err ){
				if( err ){
					console.error( err )
				}else{
					next()
				}
			});
			break;
	}
	
});

worker.send( "createmessages" );