
"
 _Junc net station_:
 * TCP Client connection with or without SSL/TLS support.
 * TCP Server with or without SSL/TLS support.
   
 Uses data (net address and options) defined in `module herd.junc.net.data`.  
 
 
 #### Monitoring.
 
 Net station monitores for each registered server:
 * `Counter` of total number of opened sockets with name '_net address name_.number of sockets'.
 * `Meter` of connection rate (number of connection requests per second) with name '_net address name_.connection rate'.
 * `Meter` of send bytes as bytes per second with name '_net address name_.bytes send rate'.
 * `Meter` of send errors per second with name '_net address name_.rate of errors while sending'.
 * `Meter` of received bytes as bytes per second with name '_net address name_.bytes receive rate'.
 * `Meter` of received errors per second with name '_net address name_.rate of errors while receiving'.
 
 
 > net address name is \"net://\" + host + \":\" + port.string, which is `NetAddress.string`
 
 
 #### TCP client example.
 
 		connect<Byte[], Byte[], NetAddress>(netAddress).onComplete (
 			(NetSocket socket) {
 				socket.onData<Byte[]> (
 					(Byte[] receive) {
 						...
 					}
 				);
 				...
 				socket.publish(byteArray);
 			}
 		);
 
 > `NetStation` has to be deployed using `Junc.deployStation` or `Railway.deployStation`
    before establishing TCP client connection.
 
 
 #### TCP server example.
 
 		track.registerService<Byte[], Byte[], NetAddress>(netAddress).onComplete (
 			(JuncService<Byte[], Byte[]> service) {
 				service.onConnected (
 					(NetSocket socket) {
 						socket.onData<Byte[]> (
 							(Byte[] receive) {
 								...
 							}
 						);
 						...
 						socket.publish(byteArray);
 					}
 				);
 			}
 		);
 
 > `NetStation` has to be deployed using `Junc.deployStation` or `Railway.deployStation`
    before creating TCP server.
 
 
 #### SSL / TLS.
 
 Client or server SSL / TLS parameters may be specified using `NetAddress`:
 
 		NetAddress address = NetAddress (
 			\"host\", XXX, 0, 0, 0, false,
 			TLSParameters {
 				protocol = \"TLS\";
 				keyStorePassword = \"password\";
 				keyStorePath = \"path\";
 				keyManagerPassword = \"password\";
 				trustStorePassword = \"password\";
 				trustStorePath = \"path\";
 			}
 		);
 
   
 #### Registeration several servers with the same host:port
 
 That's possible in order to reach some scalability level.  
 Actually, of course, only one `ServerSocket` is created and listens the given host:port.
 But when new connection is requested resulting socket is passed to one of registered _servers_
 choosen by min number of already opened sockets.  
 
 > Servers with the same host:port should be registered on different tracks!
   It allows to listen incoming sockets on different tracks
   and possibly on different threads (depending on load level)
   and therefore reach target scalability level.  
 
 Example:
 
 		// server address
  		NetAddress address = NetAddress(...);

 		// register first server
 		value firstTrack = junc.newTrack();
 		firstTrack.registerService<Byte[], Byte[], NetAddress>(address).onComplete (
 			(JuncService<Byte[], Byte[]> service) {
 				...
 			}
 		);
 
 		// register second server with the same host:port as first one
 		value secondTrack = junc.newTrack();
 		secondTrack.registerService<Byte[], Byte[], NetAddress>(address).onComplete (
 			(JuncService<Byte[], Byte[]> service) {
 				...
 			}
 		);
 
 "
by( "Lis" )
native("jvm")
module herd.junc.net.station "0.1.0" {
	shared import herd.junc.api "0.1.0";
	shared import herd.junc.net.data "0.1.0";
	shared import java.base "8";
	import java.tls "8";
	import ceylon.collection "1.2.2";
	import ceylon.interop.java "1.2.2";
}
