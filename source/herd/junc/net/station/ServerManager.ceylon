import herd.junc.api {
	Promise,
	Context,
	JuncService,
	Deferred,
	InvalidServiceError,
	Junc,
	Workshop,
	Connector,
	Resolver,
	JuncSocket
}
import ceylon.collection {

	HashMap
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Net workshop and connector."
by( "Lis" )
class ServerManager (
	shared actual Junc junc,
	shared actual Context context,
	Integer defaultTimeOut,
	Integer defaultBufferSize,
	Integer defaultTimeIdle
)
		satisfies ServerOwner & Workshop<Byte[], Byte[], NetAddress> & Connector<Byte[], Byte[], NetAddress>
{
	
	"`ServerManager`: default buffer size to be > 0."
	assert ( defaultBufferSize > 0 );
	
	
	HashMap<NetAddress, NetServer> servers = HashMap<NetAddress, NetServer>();
	
	"Client sockets - works on another track."
	ClientSocketGroup clients = ClientSocketGroup (
		junc.newTrack().context,
		ClientSocketFactory( emptySocketMetric, defaultBufferSize )
	);
	
	"Finishing connections."
	ConnectionFinisher finisher = ConnectionFinisher( context, junc, defaultTimeOut, clients );
	
	"Creates new service."
	JuncService<Byte[], Byte[]> doCreateService( NetAddress address, Context context ) {
		// exclude service name from actual address - since unused
		if ( servers.empty && finisher.empty ) { this.context.execute( socketing ); }
		if ( exists server = servers.get( address ) ) {
			// server already exists - add new service to
			return server.addService( context );
		}
		else {
			// create new server and attach service to
			NetServer server = NetServer( address, this, junc.monitor, defaultBufferSize );
			servers.put( server.address, server );
			return server.addService( context );
		}
	}

	
	"1. accepting of all servers
	 2. finishing all client sockets"
	void socketing() {
		for ( server in servers.items ) { server.accept(); }
		finisher.finishConnection();
		if ( !servers.empty || !finisher.empty ) { context.execute( socketing ); }
	}

	
	shared actual Promise<JuncSocket<FromService, ToService>> connect<FromService, ToService> (
		NetAddress address, Context clientContext
	) {
		Deferred<NetSocket> def = clientContext.newResolver<NetSocket>();
		if ( is Promise<JuncSocket<FromService, ToService>> prom = def.promise ) {
			if ( servers.empty && finisher.empty ) { context.execute( socketing ); }
			finisher.connect( address, clientContext, def );
			return prom;
		}
		else {
			return clientContext.rejectedPromise( InvalidServiceError() );
		}
	}
	
	shared actual Promise<JuncService<FromService, ToService>> provideService<FromService, ToService> (
		NetAddress address, Context serviceContext
	) {
		try {
			value def = serviceContext.newResolver<JuncService<FromService, ToService>>();
			if ( is Resolver<JuncService<Byte[], Byte[]>> resolver = def ) {
				resolver.resolve( doCreateService( address, serviceContext ) );
				return def.promise;
			}
			else {
				return serviceContext.rejectedPromise( InvalidServiceError() );
			}
		}
		catch ( Throwable err ) {
			return serviceContext.rejectedPromise( err );
		}
	}
	
	
	// to be called from track
	shared actual void removeServer( NetServer server ) {
		servers.remove( server.address );
	}
	
}
