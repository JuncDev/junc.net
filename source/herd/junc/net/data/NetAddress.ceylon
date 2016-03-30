import herd.junc.api {
	JuncAddress
}


"Address to connect to _net station_.  
 Net addresses are compared ([[equals]] method) by host and port! Other options are not included in comparison."
by( "Lis" )
shared class NetAddress (
	"Connection host."
	shared String host,
	"Connection port."
	shared Integer port,
	"Timeout in milliseconds used for connection.  Not applied If <= 0."
	shared Integer connectionTimeOut = 0,
	"Time idle in milliseconds (socket will be closed if no bytes received during this time).  Not applied If <= 0."
	shared Integer timeIdle = 0,
	"Size of the socket buffer."
	shared Integer bufferSize = 0,
	"Disable/enable Nagle's algorithm."
	shared Boolean tcpNoDelay = false,
	"Optional SSL/TLS parameters used for connection."
	shared TLSParameters? tls = null
)
		extends JuncAddress()
{
	
	shared actual Boolean equals( Object that ) {
		if ( is NetAddress that ) {
			return host == that.host && port == that.port;
		}
		else {
			return false;
		}
	}

	
	shared actual String string => "net://" + host + ":" + port.string;
	
	shared actual Integer calculateHash() => 41 * ( 41 * ( 41 * "net://".hash + host.hash ) + port ) + 17;
	
}
