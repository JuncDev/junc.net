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
	JuncSocket,
	Message,
	JuncTrack
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
	JuncTrack track,
	Context clientGroupContext,
	Integer defaultTimeOut,
	Integer defaultBufferSize,
	Integer defaultTimeIdle
)
		satisfies ServerOwner & Workshop<Byte[], Byte[], NetAddress> & Connector<Byte[], Byte[], NetAddress>
{
	
	"`ServerManager`: default buffer size to be > 0."
	assert ( defaultBufferSize > 0 );
	
	
	shared actual Context context => track.context;
	
	HashMap<NetAddress, NetServer> servers = HashMap<NetAddress, NetServer>();
	
	"Client sockets - works on another track."
	ClientSocketGroup clients = ClientSocketGroup (
		clientGroupContext,
		ClientSocketFactory( emptySocketMetric, defaultBufferSize )
	);
	
	"Finishing connections."
	ConnectionFinisher finisher = ConnectionFinisher( context, junc, defaultTimeOut, clients );
	
	"Creates new service."
	Message<JuncService<Byte[], Byte[]>, Null> doCreateService( NetAddress address, JuncTrack track ) {
		// exclude service name from actual address - since unused
		if ( servers.empty && finisher.empty ) { this.context.execute( socketing ); }
		if ( exists server = servers.get( address ) ) {
			// server already exists - add new service to
			return server.addService( track );
		}
		else {
			// create new server and attach service to
			NetServer server = NetServer( address, this, junc.monitor, defaultBufferSize );
			servers.put( server.address, server );
			return server.addService( track );
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
	
	shared actual Promise<Message<JuncService<Send, Receive>, Null>> provideService<Send, Receive> (
		NetAddress address, JuncTrack serviceTrack
	) {
		try {
			value def = serviceTrack.context.newResolver<Message<JuncService<Send, Receive>, Null>>();
			if ( is Resolver<Message<JuncService<Byte[], Byte[]>, Null>> resolver = def ) {
				resolver.resolve (
					doCreateService( address, serviceTrack )
				);
				return def.promise;
			}
			else {
				return serviceTrack.context.rejectedPromise( InvalidServiceError() );
			}
		}
		catch ( Throwable err ) {
			return serviceTrack.context.rejectedPromise( err );
		}
	}
	
	
	// to be called from track
	shared actual void removeServer( NetServer server ) {
		servers.remove( server.address );
	}
	
}
