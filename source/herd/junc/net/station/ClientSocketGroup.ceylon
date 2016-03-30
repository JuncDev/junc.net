import herd.junc.api {
	Resolver,
	Context,
	ServiceClosedError
}
import java.nio.channels {

	SocketChannel
}
import java.util.concurrent.locks {

	ReentrantLock
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Group of client sockets.  Performs read / write operations."
by( "Lis" )
class ClientSocketGroup (
	"context this group works on" Context context,
	"factory to create sockets" ClientFactory factory
)
		extends ServerSocketGroup( factory )
		satisfies SocketContainer 
{
	class SocketConnection (
		shared NetAddress address,
		shared NetSocket clientSocket,
		shared NetSocket serverSocket,
		shared SocketChannel channel,
		shared Resolver<NetSocket> clientResolver
	) {
		shared variable SocketConnection? next = null;
		shared variable SocketConnection? previous = null;
	}
	
	variable SocketConnection? head = null;
	ReentrantLock lock = ReentrantLock();
	
	shared actual Boolean empty => super.empty && ! head exists;
	
	shared actual void putConnected (
		NetAddress address, NetSocket clientSocket, NetSocket serverSocket,
		SocketChannel channel, Resolver<NetSocket> clientResolver
	) {
		lock.lock();
		try {
			SocketConnection s = SocketConnection( address, clientSocket, serverSocket, channel, clientResolver );
			s.next = head;
			if ( exists h = head ) { h.previous = s; }
			else if ( super.empty ) { context.execute( process ); }
			head = s;
		}
		finally { lock.unlock(); }
	}
	
	
	shared actual default void close() {
		super.close();
		
		// close all connected but not pushed sockets
		lock.lock();
		variable SocketConnection? h = head;
		head = null;
		lock.unlock();
		while ( exists s = h ) {
			h = s.next;
			s.channel.close();
			s.serverSocket.close();
			s.clientResolver.reject( ServiceClosedError() );
		}
	}
	
	shared actual default void process() {
		// read / write
		super.process();
		
		// push connected sockets
		lock.lock();
		SocketConnection? first = head;
		head = null;
		lock.unlock();
		variable SocketConnection? h = first;
		while ( exists s = h ) {
			h = s.next;
			try {
				addSocket( s.address, s.serverSocket, s.channel );
				s.clientResolver.resolve( s.clientSocket );
			}
			catch ( Throwable err ) {
				s.channel.close();
				s.clientResolver.reject( err );
			}
		}
		
		if ( !empty ) { context.execute( process ); }
	}
	
}
