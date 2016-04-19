import herd.junc.api {
	JuncService,
	Context,
	Emitter,
	Publisher,
	ServiceClosedError,
	Registration,
	JuncSocket
}
import java.util.concurrent.atomic {

	AtomicBoolean
}
import java.nio.channels {

	SocketChannel
}

import herd.junc.api.monitor {

	Counter,
	Meter
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Contains sockets and periodicaly reads them on specified context."
by( "Lis" )
class NetService (
	shared actual NetAddress address,
	"Context service to work on" shared Context context,
	"Events emitter" shared Emitter<NetSocket> slot,
	"Publisher to publish on `events`." shared Publisher<NetSocket> eventSlot,
	"Number of sockets counter." Counter socketsNum,
	"Service connection rate." Meter connectionRate,
	"Instrumenting sockets." SocketMetric metric,
	"Default size of io buffer." Integer defaultBufferSize
)
		satisfies JuncService<Byte[], Byte[]>
{
	
	ServerSocketGroup group = ServerSocketGroup (
		if ( exists tls = address.tls )
		then TLSServiceSocketFactory (
			metric, address.bufferSize > 0 then address.bufferSize else defaultBufferSize, tls
		)
		else ServiceSocketFactory ( metric, address.bufferSize > 0 then address.bufferSize else defaultBufferSize )
	);
	
	shared actual Integer numberOfSockets => group.socketsNumber;
	
	shared variable NetService? next = null;
	shared variable NetService? previous = null;
	
	
	"is service closed"
	AtomicBoolean atomicClosed = AtomicBoolean( false );
	shared actual Boolean closed => atomicClosed.get();
	
	
	"blocking - avoiding connecting and registering services"
	AtomicBoolean atomicBlock = AtomicBoolean( false );
	shared actual Boolean blocked => atomicBlock.get();
	assign blocked => atomicBlock.set( blocked );

	
	"Performs - reading operations."
	void reading() {
		if ( !closed ) {
			group.process();
			if ( group.socketsNumber > 0 ) { context.execute( reading ); }
		}
	}
	
	class SocketAdding (
		"Client socket resolves the promise when socket added." shared NetSocket clientSocket,
		"Service socket to read / write by service." shared NetSocket serverSocket,
		"Channel to get / put bytes." shared SocketChannel channel
	) {}
	
	
	"Adds new socket - to be performed from `context` in order to avoid thread concurency."
	void doAdding( SocketAdding description ) {
		if ( closed ) {
			eventSlot.error( ServiceClosedError() );
			description.clientSocket.close();
		}
		else {
			try {
				group.addSocket( address, description.serverSocket, description.channel );
			}
			catch ( Throwable err ) {
				description.clientSocket.error( err );
				description.clientSocket.close();
				try { description.channel.close(); }
				catch ( Throwable closeErr ) {}
				return;
			}
			description.serverSocket.onClose( socketsNum.decrement );
			socketsNum.increment();
			connectionRate.tick();
			if ( group.socketsNumber == 1 ) { context.execute( reading ); }
		}
	}
	
	"Closes this service - to be called from `context`."
	void doClose() {
		group.close();
		eventSlot.close();
	}
	
	
	shared actual void close() {
		// close service on service context - in order to avoid thread concurency
		if ( atomicClosed.compareAndSet( false, true ) ) { context.execute( doClose ); }
	}
	
	
	// calls doAdding on service context in order to avoid thread concurency
	"Returns promise on service context resolved with `clientSocket`."
	shared void addSocket(
		"Client socket resolves the promise when socket added." NetSocket clientSocket,
		"Service socket to read / write by service." NetSocket serverSocket,
		"Channel to get / put bytes" SocketChannel channel
	) {
		eventSlot.publish<NetSocket>( clientSocket );
		context.executeWithArgument( doAdding, SocketAdding( clientSocket, serverSocket, channel ) );
	}
	
	
	shared actual Registration onClose( void close() ) => slot.onClose( close );
	
	shared actual Registration onConnected( void connected(JuncSocket<Byte[], Byte[]> socket) )
			=> slot.onData( connected );
	
	shared actual Registration onError( void error(Throwable err) ) => slot.onError( error );
	
}
