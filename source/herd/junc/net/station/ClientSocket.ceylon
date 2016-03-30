import java.nio.channels {

	SocketChannel,
	Channel
}
import java.nio {

	ByteBuffer
}
import ceylon.collection {

	LinkedList
}
import herd.junc.net.data {

	NetAddress,
	NetSocket
}


"Asynchronous socket."
by( "Lis" )
class ClientSocket (
	"_Junc_ socket to read from / write to."
	NetSocket juncSocket,
	"Net socket channel - to be already connected."
	shared SocketChannel channel,
	"Buffer used for io operations."
	ByteBuffer byteBuffer,
	"Address this socket utilizes."
	shared NetAddress address,
	"Instrumenting this socket."
	SocketMetric socketMetric
)
	satisfies NetClient
{
	
	try {
		channel.socket().sendBufferSize = byteBuffer.capacity();
		channel.socket().receiveBufferSize = byteBuffer.capacity();
		channel.socket().tcpNoDelay = address.tcpNoDelay;
	}
	catch ( Throwable err ) {}
	
	
	"previous time read done - to take into account [[NetAddress.timeIdle]]"
	variable Integer prevReadTime = -1;
	
	"data to be written"
	LinkedList<ByteBuffer> buffers = LinkedList<ByteBuffer>();
	
	
	void write( Byte[] bytes ) {
		try {
			// put bytes to be written to `buffers` queue, they will be written within `process` method
			Integer n = bytes.size;
			ByteBuffer writeBuffer = ByteBuffer.allocate( n );
			for ( byte in bytes ) { writeBuffer.put( byte ); }
			writeBuffer.flip();
			buffers.add( writeBuffer );
		}
		catch ( Throwable err ) {
			socketMetric.sendError();
			juncSocket.error( err );
		}
	}

	juncSocket.onData( write );
	
	
	shared actual default void close() {
		try {
			channel.close();
		}
		catch( Throwable err ) {}
		juncSocket.close();
	}
	
	
	"Reads socket channel data to buffer.
	 Returns number of read bytes or -1 if connection has been closed."
	shared default Integer readFromChannel( ByteBuffer byteBuffer ) => channel.read( byteBuffer );
	
	"Writes buffer to socket channel.
	 Returns number of actually written bytes."
	shared default Integer writeToChannel( ByteBuffer byteBuffer ) => channel.write( byteBuffer );
	
	
	shared actual void process() {
		if ( ( channel of Channel ).open && channel.connected ) {
			try {
				// read from socket
				byteBuffer.clear();
				Integer bytesRead = readFromChannel( byteBuffer );
				if ( bytesRead.positive ) {
					// bytes have been read from socket
					prevReadTime = system.milliseconds; 
					socketMetric.bytesReceived( bytesRead );
					byteBuffer.flip();
					juncSocket.publish( byteBuffer.array().iterable.take( bytesRead ).sequence() );
				}
				else if ( bytesRead.negative ) {
					// socket has been closed
					close();
				}
				else {
					// socket is empty - check time idle
					if ( address.timeIdle.positive ) {
						if ( prevReadTime.positive ) {
							if ( system.milliseconds - prevReadTime > address.timeIdle ) {
								// TODO: has error to be send - ?
								// close since time idle reached
								close();
							}
						}
						else { prevReadTime = system.milliseconds; }
					}
				}
				
				// write to socket
				if ( !bytesRead.negative, exists writeBuf = buffers.first ) {
					Integer n = writeToChannel( writeBuf );
					if ( n > 0 ) { socketMetric.bytesSend( n ); }
					else if ( n < 0 ) { close(); }
					if ( !writeBuf.hasRemaining() ) { buffers.accept(); }
				}
			}
			catch ( Throwable err ) {
				juncSocket.error( err );
				// close socket - since exceptions mainly occured when channel has been closed
				close();
			}
		}
		else {
			close();
		}
	}
	
}
