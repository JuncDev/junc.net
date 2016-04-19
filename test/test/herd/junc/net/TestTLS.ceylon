import herd.junc.api.monitor {
	Priority
}
import herd.junc.net.station {
	NetStation
}
import herd.junc.core {
	startJuncCore,
	JuncOptions,
	Railway,
	LogWriter
}
import herd.junc.net.data {
	NetAddress,
	TLSParameters,
	NetSocket
}
import herd.junc.api {
	Station,
	JuncTrack,
	Junc,
	JuncService,
	Promise
}
import herd.asynctest {
	sequential,
	TestSuite,
	TestInitContext,
	AsyncTestContext
}
import ceylon.test {
	test
}
import herd.asynctest.match {
	EqualTo
}


sequential
shared class TLSTest() satisfies TestSuite {
	
	variable Railway? railway = null;
	
	
	shared actual void dispose() {
		if ( exists r = railway ) {
			r.stop();
		}
	}
	
	shared actual void initialize( TestInitContext initContext ) {	
		startJuncCore (
			JuncOptions {
				monitorPeriod = 0;
			}
		).onComplete (
			( Railway railway ) {
				this.railway = railway;
				
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
					(Object obj) => initContext.proceed(),
					(Throwable err) => initContext.abort( err )
				);
			}
		);
	}
	
	shared test void runTLSTest( AsyncTestContext context ) {
		assert ( exists r = railway );
		
		context.start();
		r.deployStation( TLSTestStation( context ) ).onError (
			(Throwable err) {
				context.abort( err, "TLS test station deploying" );
				context.complete();
			}
		);
	}
	
}

class TLSTestStation( AsyncTestContext context ) satisfies Station 
{
	
	Integer totalConnections = 2;
	variable Integer connections = totalConnections;
	
	NetAddress serviceAddress = NetAddress (
		"localhost", 27618, 0, 0, 0, false,
		TLSParameters {
			protocol = "TLS";
			//keyStorePassword = "Kbctyjr1";
			//keyStorePath = "E:\\Develop\\ll.jks";
			//keyManagerPassword = "Kbctyjr1";
			//trustStorePassword = "Kbctyjr1";
			//trustStorePath = "E:\\Develop\\ll.jks";
		}
	);
	
	NetAddress clientAddress = NetAddress (
		"localhost", 27618, 0, 0, 0, false,
		TLSParameters {
			protocol = "TLS";
			//keyStorePassword = "Kbctyjr1";
			//keyStorePath = "E:\\Develop\\ll.jks";
			//keyManagerPassword = "Kbctyjr1";
			//trustStorePassword = "Kbctyjr1";
			//trustStorePath = "E:\\Develop\\ll.jks";
		}
	);
	
	
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
				Integer timeStamp = fromBytes( receive );
				socket.publish( toBytes( timeStamp ) );
			}
		);
		socket.onError (
			(Throwable reason) {
				context.fail( reason, "service socket received" );
				context.complete();
			}
		);
	}
	
	void connection( NetSocket socket ) {
		Integer actual = system.milliseconds;
		socket.onData<Byte[]> (
			(Byte[] receive) {
				Integer timeStamp = fromBytes( receive );
				context.assertThat( timeStamp, EqualTo( actual ), "timestamp", true );
				socket.close();
			}
		);
		socket.onClose (
			() {
				if ( -- connections < 1 ) { context.complete(); }
			}
		);
		socket.onError (
			(Throwable reason) {
				context.fail( reason, "client socket received" );
				context.complete();
			}
		);
		socket.publish( toBytes( actual ) );
	}
	
	shared actual Promise<Object> start( JuncTrack track, Junc junc ) {		
		return track.registerService<Byte[], Byte[], NetAddress>( serviceAddress ).onComplete (
			(JuncService<Byte[], Byte[]> service) {
				service.onConnected( serviceConnected );
				for ( i in 0 : totalConnections ) {
					Integer index = i;
					track.connect<Byte[], Byte[], NetAddress>( clientAddress ).onComplete (
						connection,
						(Throwable err) {
							context.fail( err, "connection ``index`` to net" );
							context.complete();
						}
					);
				}
			},
			(Throwable err) {
				context.fail( err, "net service registration" );
				context.complete();
			}
		);
	}
	
}
