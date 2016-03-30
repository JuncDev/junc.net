import java.nio.channels {

	SocketChannel
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Represents a group of sockets - a number of sockets work on a one context.  
 Default implementation is thread unsafe - to be called from a single context."
by( "Lis" )
interface SocketGroup
{
	"number of sockets"
	shared formal Integer socketsNumber;	
	
	"`true` if contains no any socket and `false` otherwise"
	shared formal Boolean empty;
	
	
	"Adds socket to the group, socket to be already connected.  May throws if errored."
	shared formal void addSocket (
		"Socket address." NetAddress address,
		"_Junc_ socket to read from / write to." NetSocket juncSocket,
		"Net socket - to be already connected." SocketChannel channel
	);

	"Forces read / write operations from group sockets.  
	 To be called periodically"
	shared formal void process();
	
	"Closes all sockets in the group."
	shared formal void close();
	
}
