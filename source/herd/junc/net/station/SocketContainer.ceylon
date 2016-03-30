import herd.junc.api {

	Resolver
}
import java.nio.channels {

	SocketChannel
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Contains sockets."
by( "Lis" )
interface SocketContainer
{
	"Puts connected socket to the container - may be called from another thread."
	shared formal void putConnected (
		NetAddress address,
		NetSocket clientSocket,
		NetSocket serverSocket,
		SocketChannel channel,
		Resolver<NetSocket> clientResolver
	);
}
