import java.nio.channels {

	SocketChannel
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Interface of net clients factory."
by( "Lis" )
interface ClientFactory
{
	
	"Creates new client.  Returns created client.  May throw an error if unable to create"
	shared formal NetClient createClient (
		"_Junc_ socket to read from / write to." NetSocket juncSocket,
		"Net socket - to be already connected." SocketChannel channel,
		"Address with parameters." NetAddress address
	);
}
