import java.nio.channels {
	SocketChannel
}
import herd.junc.net.data {
	NetAddress,
	NetSocket
}


"Creates simple server net sockets."
by( "Lis" )
class ServiceSocketFactory (
	"Instrumenting sockets." SocketMetric socketMetric,
	"Default buffer size." Integer defaultBufferSize
)
		extends BaseSocketFactory()
{
	
	"`ServiceSocketFactory`: default buffer size to be > 0."
	assert ( defaultBufferSize > 0 );
	
	
	shared actual NetClient createClient (
		NetSocket juncSocket, SocketChannel channel, NetAddress address
	) {
		return ClientSocket (
			juncSocket,
			channel,
			getBufferOfSize( address.bufferSize > 0 then address.bufferSize else defaultBufferSize ),
			address,
			socketMetric
		);
	}
}
