import herd.junc.api {

	Promise,
	JuncTrack,
	Junc,
	Station,
	Registration
}


"Net station:
 * TCP Client connection with or without SSL/TLS support.
 * TCP Server with or without SSL/TLS support.
 
 >Default parameters may be overriden using `NetAddress`.
 
 "
by( "Lis" )
throws( `class AssertionError`, "'defaultBufferSize' has to be > 0." )
shared class NetStation (
	"Default size of io buffer. To be > 0."
	Integer defaultBufferSize = 8192,
	"Default time idle in milliseconds (closing connection if no data read during this time). Not applied if <= 0."
	Integer defaultTimeIdle = -1,
	"Default connection time out in milliseconds. Not applied if <= 0."
	Integer defaultTimeOut = -1
)
		satisfies Station
{
	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {
		value manager = ServerManager( junc, track.context, defaultTimeOut, defaultBufferSize, defaultTimeIdle );
		
		return track.registerWorkshop( manager ).and<Object, Registration> (
			track.registerConnector( manager ),
			( Registration val, Registration otherVal ) {
				return track.context.resolvedPromise( this );
			}
		);
	}
	
}
