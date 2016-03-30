import java.nio {
	ByteBuffer
}
import ceylon.collection {
	HashMap
}


"Abstract socket factory."
by( "Lis" )
abstract class BaseSocketFactory()
		satisfies ClientFactory
{
	HashMap<Integer, ByteBuffer> buffers = HashMap<Integer, ByteBuffer>();
	
	shared ByteBuffer getBufferOfSize( Integer bufferSize ) {
		if ( exists buf = buffers.get( bufferSize ) ) {
			return buf;
		}
		else {
			ByteBuffer byteBuffer = ByteBuffer.allocate( bufferSize );
			buffers.put( bufferSize, byteBuffer );
			return byteBuffer;
		}
	}
	
}