import herd.junc.net.data {
	TLSParameters,
	NetAddress,
	NetSocket
}
import java.nio.channels {
	SocketChannel
}
import javax.net.ssl {
	SSLEngine
}


"Creates secure service sockets."
by( "Lis" )
class TLSServiceSocketFactory(
	"Instrumenting sockets." SocketMetric socketMetric,
	"Default buffer size." Integer defaultBufferSize,
	"tls / SSL parameters." TLSParameters tls
)
		extends BaseSocketFactory()
{
	
	"`TLSServiceSocketFactory`: default buffer size to be > 0."
	assert ( defaultBufferSize > 0 );
	
	
	SSLInitializer initializer = SSLInitializer( tls );
	
	
	shared actual NetClient createClient (
		NetSocket juncSocket, SocketChannel channel, NetAddress address
	) {
		SSLEngine sslEngine = initializer.createSSLEngine( address.host, address.port, false );
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
	
}
