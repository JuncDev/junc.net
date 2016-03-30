import herd.junc.api {

	Station,
	Promise,
	JuncTrack,
	Junc,
	JuncService,
	PeriodicTimeRow,
	Timer,
	TimeEvent
}
import herd.junc.api.monitor {

	Counter,
	Average,
	Priority,
	LogWriter,
	Meter
}
import herd.junc.net.station {

	NetStation
}
import herd.junc.net.data {
	
	NetAddress,
	NetSocket
}
import herd.junc.core {

	startJuncCore,
	Railway,
	JuncOptions
}


shared void runNetTest() {
	print( "start net testing" );
	
	startJuncCore (
		JuncOptions {
			monitorPeriod = 10;
		}
	).onComplete (
		( Railway railway ) {
			railway.addMetricWriter( MetricWriterImpl() );
			railway.addLogWriter (
				object satisfies LogWriter {
					shared actual void writeLogMessage (
						String identifier,
						Priority priority,
						String message,
						Throwable? throwable
					) {
						String str = if ( exists t = throwable ) then " with error ``t.message```" else "";
						print( "``priority``: ``identifier`` sends '``message``'``str``" );
					}
				}
			);
			
			railway.deployStation( NetStation() ).onComplete (
				( Object obj ) {
					railway.deployStation( TestNetStation() );
				}
			);
		}
	);
	
}


class TestNetStation() satisfies Station
{
	NetAddress address = NetAddress( "", 27618 );
	
	String scoketsNumber = "socketsNumber";
	String responseRate = "responseRate";
	String serverRate = "serverRate";
	String messageRate = "messageRate";
	
	variable Counter? sockets = null;
	variable Average? response = null;
	variable Average? responseServer = null;
	variable Meter? messages = null;
	
	variable JuncTrack? track = null;
	
	
	Integer socketsLimit = 50;
	

	Integer fromBytes( Byte[] bytes ) {
		if ( bytes.size == 8 ) {
			variable Integer nOctad = 0;
			variable Integer index = 0;
			for( byte in bytes ) {
				nOctad = nOctad.or( byte.unsigned.leftLogicalShift( 8 * index ) );
				index ++;
			}
			return nOctad;
		}
		return 0;
	}
	
	Byte[] toBytes( Integer octad ) {
		variable Integer nCurrent = octad;
		Array<Byte> bytes = Array<Byte>( [Byte(0)].repeat( 8 ) ); 
		for( i in 0 : 8 ) {
			Integer n = nCurrent;
			nCurrent = nCurrent.rightLogicalShift( 8 );
			bytes.set( i, Byte( n.and( #FF ) ) );
		}
		return bytes.sequence();
	}
	

	void serviceConnected( NetSocket socket ) {
		socket.onData<Byte[]> (
			(Byte[] receive) {
				if ( exists m = messages ) { m.tick(); }
				Integer timeStamp = fromBytes( receive );
				if ( exists ave = responseServer ) {
					ave.sample( ( system.milliseconds - timeStamp ).float );
				}
				socket.publish( toBytes( timeStamp ) );
			}
		);
		socket.onClose( () => print( "service socket closed" ) );
		socket.onError( (Throwable reason) => print( "service socket error ``reason``" ) );
	}
	
	void connection( NetSocket socket ) {
		if ( exists s = sockets ) { s.increment(); }
		socket.onData<Byte[]> (
			(Byte[] receive) {
				Integer timeStamp = fromBytes( receive );
				if ( exists ave = response ) {
					ave.sample( ( system.milliseconds - timeStamp ).float );
				}
				socket.publish( toBytes( system.milliseconds ) );
			}
		);
		socket.onClose( () => print( "client socket closed" ) );
		socket.onError( (Throwable reason) => print( "client socket error ``reason``" ) );
		socket.publish( toBytes( system.milliseconds ) );
	}
	
	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {		
		
		process.readLine();
		
		sockets = junc.monitor.counter( scoketsNumber );
		response = junc.monitor.average( responseRate );
		responseServer = junc.monitor.average( serverRate );
		messages = junc.monitor.meter( messageRate );
		
		value connectionTrack = junc.newTrack();
		this.track = junc.newTrack();
		return track.registerService<Byte[], Byte[], NetAddress>( address ).onComplete (
			(JuncService<Byte[], Byte[]> service) {
				service.onConnected( serviceConnected );
				Timer t = connectionTrack.createTimer( PeriodicTimeRow( 200, socketsLimit ) );
				t.onData (
					( TimeEvent event ) {
						for ( i in 0:10 ) {
							connectionTrack.connect<Byte[], Byte[], NetAddress>( address ).onComplete (
								connection,
								(Throwable err)=> print( "error during connection ``err``" )
							);
						}
					}
				);
				t.start();
			},
			(Throwable err) => print( "cann't register net service due to ``err``" )
		);
	}
	
}
