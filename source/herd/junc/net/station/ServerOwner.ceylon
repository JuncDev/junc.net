import herd.junc.api {

	Junc,
	Context
}


"Owns servers."
see( `class NetServer` )
by( "Lis" )
interface ServerOwner
{
	"junc reference"
	shared formal Junc junc;
	
	"context the owner works on"
	shared formal Context context;

	"remove server from the owner"
	shared formal void removeServer( NetServer server );
}
