

"Client authorization type."
see( `value TLSParameters.clientAuth` )
by( "Lis" )
shared class ClientAuth
	of required | requested | none
{
	"Client authorization is required."
	shared new required {}
	
	"Client authorization is requested but not required."
	shared new requested {}
	
	"Client authorization is not required."
	shared new none {}
}
