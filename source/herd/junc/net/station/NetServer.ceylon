import herd.junc.api {
	JuncService,
	JuncTrack,
	Message
}
import java.nio.channels {

	ServerSocketChannel,
	SocketChannel
}
import java.net {

	InetSocketAddress
}
import herd.junc.api.monitor {

	Counter,
	Meter,
	monitored,
	Monitor
}
import herd.junc.net.data {

	NetAddress,
	NetSocket,
	netMonitored
}


"Server as a collection of services.  Throws some exceptions at initializer - see java `ServerSocketChannel`."
by( "Lis" )
class NetServer (
	"Address to bind to." NetAddress bindAddress,
	"Owner of this server." ServerOwner owner,
	"Monitor this server." Monitor monitor,
	"Default size of io buffer." Integer defaultBufferSize
) {
	
	ServerSocketChannel server = ServerSocketChannel.open();
	server.configureBlocking( false );
	if ( bindAddress.host.empty ) {
		if ( bindAddress.port >= 0 ) { server.bind( InetSocketAddress( bindAddress.port ) ); }
		else { server.bind( null ); }
	}
	else {
		if ( bindAddress.port >= 0 ) { server.bind( InetSocketAddress( bindAddress.host, bindAddress.port ) ); }
		else { server.bind( InetSocketAddress( bindAddress.host, 0 ) ); }
	}


	"Server address." shared NetAddress address;
	if ( is InetSocketAddress inetAddress = server.localAddress ) {
		address = NetAddress (
			inetAddress.hostString, inetAddress.port,
			bindAddress.connectionTimeOut, bindAddress.timeIdle, bindAddress.bufferSize, bindAddress.tcpNoDelay,
			bindAddress.tls
		);
	}
	else {
		address = bindAddress;
	}

	
	"Number of sockets counter."
	Counter socketsNum = monitor.counter( address.string + monitored.delimiter + monitored.numberOfSockets );
	"Service connection rate."
	Meter connectionRate = monitor.meter( address.string + monitored.delimiter + monitored.connectionRate );
	
	"Instrumenting server sockets."
	SocketMetric metric = SocketMetricReal (
		monitor.meter( address.string + monitored.delimiter + netMonitored.bytesSendRate ),
		monitor.meter( address.string + monitored.delimiter + netMonitored.rateOfErrorsWhileSending ),
		monitor.meter( address.string + monitored.delimiter + netMonitored.bytesReceiveRate ),
		monitor.meter( address.string + monitored.delimiter + netMonitored.rateOfErrorsWhileReceiving )
	);	

	
	variable Boolean running = true;
	
	variable NetService? first = null;
	
	
	// to be executed from server context - i.e. owner track
	void closeAndRemove() {
		owner.removeServer( this );
		close();
	}
	
	// to be executed from server context - i.e. owner track
	void removeService( NetService service ) {
		if ( running ) {
			if ( exists n = service.next ) {
				if ( exists p = service.previous ) {
					p.next = service.next;
					n.previous = p;
				}
				else {
					n.previous = null;
					first = n;
				}
			}
			else if ( exists p = service.previous ) { p.next = null; }
			else {
				first = null;
				// remove server since all services have been closed
				closeAndRemove();
			}
		}
		service.next = null;
		service.previous = null;
	}
	
	"returns service with min number of sockets"
	NetService? minSocketService() {
		variable NetService? ret = null;
		variable Integer min = -1;
		variable NetService? service = first;
		while ( exists s = service ) {
			service = s.next;
			if ( !s.blocked ) {
				if ( min == -1 ) {
					min = s.numberOfSockets;
					ret = s;
				}
				else if ( min > s.numberOfSockets ) {
					min = s.numberOfSockets;
					ret = s;
				}
			}
		}
		return ret;
	}
	
	"sends an error to all services"
	void sendErrorToAllService( Throwable err ) {
		variable NetService? service = first;
		while ( exists s = service ) {
			service = s.next;
			s.eventSlot.error( err );
		}
	}
	
	"asks server to accept socket"
	SocketChannel? acceptSocket() {
		try { return server.accept(); }
		catch ( Throwable err ) {
			monitor.logError( address.string, "when accepting new connection to server", err );
			sendErrorToAllService( err );
			closeAndRemove();
		}
		return null;
	}
	
	void logSocketError( Throwable error )
			=> monitor.logError( address.string, "service reports on an error", error );
	
	
	"accepting sockets - calls [[acceptSocket]] and if it returns new socket pushes it to the service with min number of sockets.  
	 To be called periodically"
	shared void accept() {
		if ( running ) {
			if ( exists socket = acceptSocket() ) {
				if ( exists service = minSocketService() ) {
					socket.configureBlocking( false );
					value pair = owner.junc.socketPair<Byte[], Byte[]>( service.context, service.context );
					service.addSocket( pair[0], pair[1], socket );
					// log socket error
					pair[1].onError( logSocketError );
				}
				else if ( exists f = first ) {
					// all services are blocked - reject connection and log
					socket.close();
					monitor.logError( address.string, "remote tries to connect to blocked service" );
				}
				else {	
					// all services have been closed - close server
					socket.close();
					closeAndRemove();
					first = null;
				}
			}
		}
		else { owner.removeServer( this ); }
	}
	
	"Closes all services. To be called from owner track"
	shared void close() {
		monitor.removeCounter( address.string + monitored.delimiter + monitored.numberOfSockets );
		monitor.removeMeter( address.string + monitored.delimiter + monitored.connectionRate );
		monitor.removeMeter( address.string + monitored.delimiter + netMonitored.bytesSendRate );
		monitor.removeMeter( address.string + monitored.delimiter + netMonitored.rateOfErrorsWhileSending );
		monitor.removeMeter( address.string + monitored.delimiter + netMonitored.bytesReceiveRate );
		monitor.removeMeter( address.string + monitored.delimiter + netMonitored.rateOfErrorsWhileReceiving );
		
		if ( running ) {
			try { server.close(); }
			catch ( Throwable err ) {}
			running = false;
			variable NetService? service = first;
			while ( exists s = service ) {
				service = s.next;
				s.close();
			}
		}
	}
	
	"Adds service to the server. To be called from owner track"
	shared Message<JuncService<Byte[], Byte[]>, Null> addService (
		"context service to work on" JuncTrack track
	) {
		value ev = owner.junc.messanger<NetSocket>( track.context );
		NetService service = NetService (
			address, track.context, ev[0], ev[1], socketsNum, connectionRate, metric, defaultBufferSize
		);
		return track.createMessage<JuncService<Byte[], Byte[]>, Null> (
			service,
			(Message<Null, JuncService<Byte[], Byte[]>> msg) {
				service.next = first;
				if ( exists f = first ) { f.previous = service; }
				first = service;
				service.slot.onClose( () => owner.context.executeWithArgument( removeService, service ) );
			},
			(Throwable err) {
				service.close();
			}
		);
	}
	
}
