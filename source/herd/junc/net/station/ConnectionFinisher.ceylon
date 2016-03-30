import herd.junc.api {

	Context,
	Junc,
	Deferred,
	Resolver,
	ConnectionTimeOutError,
	InvalidServiceError
}
import java.net {

	InetSocketAddress
}
import java.nio.channels {

	SocketChannel
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Finishes connections and put connected sockets to container."
by( "Lis" )
class ConnectionFinisher (
	"Context this group works on." Context context,
	"_Junc_ - used to create local sockets pair." Junc junc,
	"Default time out - time to limit connection finishing." Integer defaultTimeOut,
	"Container to store connected sockets." SocketContainer container
) {
	
	abstract class PendingSocket (
	) {
		shared variable PendingSocket? next = null;
		shared variable PendingSocket? previous = null;
		
		"Finishes connection."
		shared formal void finish();
	}
	
	
	variable PendingSocket? firstPending = null;
	
	shared Boolean empty => !firstPending exists;
	
	Anything(Throwable) errorListener( String addr ) {
		return ( Throwable error ) => junc.monitor.logError( addr, "net client reports on an error", error );
	}
	
		
	class PendingSocketImpl (
		NetAddress address,
		NetSocket clientSocket,
		NetSocket serverSocket,
		SocketChannel channel,
		Resolver<NetSocket> clientResolver,
		Integer timeOut
	)
			extends PendingSocket()
	{
		
		variable Integer startFinishingTime = 0;
		
		void remove() {
			if ( exists n = next ) {
				if ( exists p = previous ) {
					p.next = next;
					n.previous = p;
				}
				else {
					n.previous = null;
					firstPending = n;
				}
			}
			else if ( exists p = previous ) { p.next = null; }
			else { firstPending = null; }
			next = null;
			previous = null;
		}
		
		shared actual void finish() {
			try {
				if ( channel.finishConnect() ) {
					remove();
					serverSocket.onError ( 
						errorListener( address.string )
					);
					container.putConnected( address, clientSocket, serverSocket, channel, clientResolver );
				}
				else if ( timeOut.positive ){
					if ( startFinishingTime.positive ) {
						if ( system.milliseconds - startFinishingTime > timeOut ) {
							// time out - reject connection
							clientResolver.reject( ConnectionTimeOutError() );
							remove();
						}
					}
					else { startFinishingTime = system.milliseconds; }
				}
			}
			catch ( Throwable err ) {
				clientResolver.reject( err );
				remove();
			}
		}
	}
	
	
	"Connects to specified host and port.  To be called from group context."
	shared void connect (
		NetAddress address, Context clientContext, Deferred<NetSocket> resolver
	) {
		if ( address.port > 0 ) {			
			try {
				SocketChannel channel = SocketChannel.open();
				channel.configureBlocking( false );
				value socks = junc.socketPair<Byte[], Byte[]>( context, clientContext );
				if ( channel.connect( InetSocketAddress( address.host, address.port ) ) ) {
					socks[0].onError (
						errorListener( address.string )
					);
					container.putConnected( address, socks[1], socks[0], channel, resolver );
				}
				else {
					Integer timeOut = if ( address.connectionTimeOut > 0 ) then address.connectionTimeOut else defaultTimeOut;
					PendingSocketImpl pend = PendingSocketImpl( address, socks[1], socks[0], channel, resolver, timeOut );
					pend.next = firstPending;
					if ( exists f = firstPending ) { f.previous = pend; }
					firstPending = pend;
				}
			}
			catch ( Throwable err ) { resolver.reject( err ); }
		}
		else { resolver.reject( InvalidServiceError() ); }
	}
	
	"finishes connections - to be called periodically in order to check if some connections has been established"
	shared void finishConnection() {
		variable PendingSocket? sock = firstPending;
		while ( exists s = sock ) {
			sock = s.next;
			s.finish();
		}
	}
	
}
