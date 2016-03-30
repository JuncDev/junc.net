import java.nio.channels {

	SocketChannel
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Group of server sockets.  
 Not thread safe - so all operations to be performed from a single context"
by( "Lis" )
class ServerSocketGroup( "Factory to create sockets." ClientFactory factory )
	satisfies SocketGroup
{
	
	abstract class SocketItem( shared NetClient client ) {
		shared variable SocketItem? next = null;
		shared variable SocketItem? previous = null;
		
		shared formal void close();
	}
	
	variable SocketItem? head = null;
	shared actual default Boolean empty => ! head exists;
		
	variable Integer totalSockets = 0;
	shared actual Integer socketsNumber => totalSockets;

	
	class SocketItemImpl( NetClient client ) extends SocketItem( client ) {
		shared actual void close() {
			client.close();
			if ( exists n = next ) {
				if ( exists p = previous ) {
					p.next = next;
					n.previous = p;
				}
				else {
					n.previous = null;
					head = n;
				}
			}
			else if ( exists p = previous ) { p.next = null; }
			else { head = null; }
			next = null;
			previous = null;
			totalSockets --;
		}
	}


	shared actual void addSocket (
		NetAddress address,
		NetSocket juncSocket,
		SocketChannel channel
	) {
		SocketItemImpl impl = SocketItemImpl( factory.createClient( juncSocket, channel, address ) );
		juncSocket.onClose( impl.close );
		impl.previous = null;
		impl.next = head;
		if ( exists h = head ) { h.previous = impl; }
		head = impl;
		totalSockets ++;
	}
	
	shared actual default void close() {
		variable SocketItem? sock = head;
		while ( exists s = sock ) {
			sock = s.next;
			s.client.close();
		}
		head = null;
		totalSockets = 0;
	}
	
	shared actual default void process() {
		variable SocketItem? sock = head;
		while ( exists s = sock ) {
			sock = s.next;
			s.client.process();
		}
	}

}
