import java.nio.channels {

	SocketChannel
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}

import javax.net.ssl {
	SSLEngine
}


"Client net socket factory."
by( "Lis" )
class ClientSocketFactory (
	"Instrumenting group sockets." SocketMetric socketMetric,
	"Default buffer size." Integer defaultBufferSize
)
		extends BaseSocketFactory()
{
	
	"`ClientSocketFactory`: default buffer size to be > 0."
	assert ( defaultBufferSize > 0 );
	
	shared actual NetClient createClient (
		NetSocket juncSocket, SocketChannel channel, NetAddress address
	) {
		if ( exists tls = address.tls ) {
			SSLInitializer initializer = SSLInitializer( tls );
			SSLEngine sslEngine = initializer.createSSLEngine( address.host, address.port, true );
			
			value socket = TLSSocket (
				juncSocket,
				channel,
				getBufferOfSize( address.bufferSize > 0 then address.bufferSize else defaultBufferSize ),
				address,
				socketMetric,
				sslEngine
			);
			// begins handshake - actual handshake will be done when bytes send
			sslEngine.beginHandshake();
			return socket;
		}
		else {
			// no TLS / SSL
			return ClientSocket (
				juncSocket,
				channel,
				getBufferOfSize( address.bufferSize > 0 then address.bufferSize else defaultBufferSize ),
				address,
				socketMetric
			);
		}
	}
	
}
