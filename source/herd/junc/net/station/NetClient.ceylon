

"client - as socket interface"
by( "Lis" )
interface NetClient
{
	"performs read / write operations from net"
	shared formal void process();
	
	"closes client"
	shared formal void close();
}
