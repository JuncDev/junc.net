import herd.junc.api {

	Junc,
	Context
}


"Owns servers."
see( `class NetServer` )
by( "Lis" )
interface ServerOwner
{
	"Junc reference."
	shared formal Junc junc;
	
	"Context the owner works on."
	shared formal Context context;

	"Removes server from the owner."
	shared formal void removeServer( NetServer server );
}
