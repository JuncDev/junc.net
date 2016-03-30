import java.nio {
	ByteBuffer
}
import java.nio.channels {
	SocketChannel
}
import herd.junc.net.data {
	NetAddress,
	NetSocket
}
import javax.net.ssl {
	SSLEngine,
	SSLEngineResult
}


interface DataNeeds of dataNeedsOk | dataNeedsNeedsData | dataNeedsEndOfFile {}
object dataNeedsEndOfFile satisfies DataNeeds {}
object dataNeedsNeedsData satisfies DataNeeds {}
object dataNeedsOk satisfies DataNeeds {}


ByteBuffer emptyBuf = ByteBuffer.allocate( 0 );


"SSL/TLS socket"
by( "Lis" )
class TLSSocket (
	"_Junc_ socket to read from / write to."
	NetSocket juncSocket,
	"Net socket channel - to be already connected."
	SocketChannel channel,
	"Buffer used for io operations."
	ByteBuffer byteBuffer,
	"Address this socket utilizes."
	NetAddress address,
	"Instrumenting this socket."
	SocketMetric socketMetric,
	"SSL engine used with io operations."
	SSLEngine sslEngine
)
		extends ClientSocket( juncSocket, channel, byteBuffer, address, socketMetric )
{
	
	Integer applicationBufferSize = sslEngine.session.applicationBufferSize;
	Integer packetBufferSize = sslEngine.session.packetBufferSize;
	ByteBuffer readAppBuf = ByteBuffer.allocate( applicationBufferSize );
	ByteBuffer readNetBuf = ByteBuffer.allocate( packetBufferSize );
	variable ByteBuffer writeNetBuf = ByteBuffer.allocate( packetBufferSize );	
	
	variable Boolean needMoreData = false;
	variable Boolean hasDataToWrite = false;
	variable Boolean hasReadNetData = false;
	variable Boolean hasAppData = false;
	
	
	shared actual void close() {
		try { sslEngine.closeInbound(); }
		catch ( Throwable err ) {}
		
		try { sslEngine.closeOutbound(); }
		catch ( Throwable err ) {}
		
		super.close();
	}
	
	shared actual Integer writeToChannel( ByteBuffer contents ) {
		// nothing to write
		if ( !contents.hasRemaining() ) {
			return 0;
		}
		
		if ( writePendingData() == dataNeedsNeedsData ) {
			return 0;
		}
		
		variable Integer actuallyWritten = 0; 
		
		while ( contents.hasRemaining() ) {
			SSLEngineResult result = sslEngine.wrap( contents, writeNetBuf );
			value status = result.status;
			if ( status == SSLEngineResult.Status.\iBUFFER_OVERFLOW ) {
				// not enough space in the net buffer
				writeNetBuf = ByteBuffer.allocate( 2 * writeNetBuf.capacity() );
			}
			else if ( status == SSLEngineResult.Status.\iBUFFER_UNDERFLOW ) {
				return 0;
			}
			else if ( status == SSLEngineResult.Status.\iCLOSED ) {
				return -1;
			}
			else if ( status == SSLEngineResult.Status.\iOK ) {
				
				// leave contents buf as it is: if we still have things to read from it then fine
				
				// write the net data
				writeNetBuf.flip();
				hasDataToWrite = writeNetBuf.hasRemaining();
				Integer writeRemaining = writeNetBuf.remaining();
				// try to flush as much net data as possible
				if ( flushNetBuffer() == dataNeedsNeedsData ) {
					// we can't write it all
					return actuallyWritten + writeRemaining - writeNetBuf.remaining();
				}
				// see if we need to send more app data
				actuallyWritten += writeRemaining;
			}
			// now check handshaking status
			value dataStatus = handshake( result.handshakeStatus );
			switch ( dataStatus )
			case ( dataNeedsEndOfFile ) {
				return -1;
			}
			case ( dataNeedsNeedsData ) {
				return actuallyWritten;
			}
			case ( dataNeedsOk ) {
				// go on
			}
		}
		return actuallyWritten;
	}
	
	DataNeeds checkForHandshake() {
		SSLEngineResult.HandshakeStatus handshakeStatus = sslEngine.handshakeStatus;
		if ( handshakeStatus != SSLEngineResult.HandshakeStatus.\iFINISHED
			&& handshakeStatus != SSLEngineResult.HandshakeStatus.\iNOT_HANDSHAKING )
		{
			// do the handshake
			return handshake( handshakeStatus );
		}
		return dataNeedsOk;
	}
	
	DataNeeds flushNetBuffer() {
		// first try to get rid of whatever we already have
		while ( writeNetBuf.hasRemaining() ) {
			Integer written = channel.write( writeNetBuf );
			if ( written == 0 ) {
				return dataNeedsNeedsData; // wait for another write event
			}
		}
		// nothing left, we can clear it and start sending what we have at hand
		hasDataToWrite = false;
		writeNetBuf.clear();
		return dataNeedsOk;
	}
	
	DataNeeds writePendingData() {
		// are we in the middle of a handshake?
		value dataCheck = checkForHandshake();
		switch ( dataCheck )
		case ( dataNeedsNeedsData ) {
			return dataNeedsNeedsData;
		}
		case ( dataNeedsEndOfFile ) {
			return dataNeedsEndOfFile;
		}
		case ( dataNeedsOk ) {
			// go on
		}
		// at this point the handshake is over and we're good to write stuff
		
		// do we have stuff remaining to write?
		if ( hasDataToWrite ) {
			if ( flushNetBuffer() == dataNeedsNeedsData ) {
				return dataNeedsNeedsData;
			}
		}
		return dataNeedsOk;
	}
	
	
	shared actual Integer readFromChannel( ByteBuffer contents ) {
		// are we in the middle of a handshake?
		value dataCheck = checkForHandshake();
		switch ( dataCheck )
		case ( dataNeedsEndOfFile ) {
			return -1;
		}
		case ( dataNeedsNeedsData ) {
			return 0;
		}
		case ( dataNeedsOk ) {
			// go on
		}
		// at this point the handshake is over and we're good to read stuff
		
		// did we have user data left over?
		if ( hasAppData ) {
			// put whatever fits and stop here it's good enough
			return putAppData( contents );
		}
		
		// at this point we have no more app data and we have space to read something in
		//READ:
		while ( true ) {
			if ( !hasReadNetData || needMoreData ) {
				Integer read = channel.read( readNetBuf );
				if ( read == -1 ) {
					return -1;
				}
				if ( read == 0 ) {
					return 0; // wait for more data
				}
			}
			// start reading from it 
			readNetBuf.flip();
			
			SSLEngineResult result = sslEngine.unwrap( readNetBuf, readAppBuf );
			
			value status = result.status;
			if ( status == SSLEngineResult.Status.\iBUFFER_OVERFLOW ) {
				return -1;
			}
			else if ( status == SSLEngineResult.Status.\iBUFFER_UNDERFLOW ) {
				hasReadNetData = readNetBuf.hasRemaining();
				if ( hasReadNetData ) {
					// put what remains at the start as if we just read it
					readNetBuf.compact();
				}
				else {
					readNetBuf.clear();
				}
				// need to read more data, start over
				needMoreData = true;
				continue;
			}
			else if ( status == SSLEngineResult.Status.\iOK || status == SSLEngineResult.Status.\iCLOSED ) {
				if ( readNetBuf.hasRemaining() ) {
					// put what remains at the start as if we just read it
					readNetBuf.compact();
				}
				else {
					readNetBuf.clear();
				}
				needMoreData = false;
				
				// now put as much of our app buf into contents
				readAppBuf.flip();
				hasAppData = true;
				// we're done
				return putAppData( contents );
			}
		}
	}
	
	Integer putAppData( ByteBuffer contents ) {
		Integer contentsRemaining = contents.remaining();
		Integer readAppBufRemaining = readAppBuf.remaining();
		Integer transfer = contentsRemaining < readAppBufRemaining then contentsRemaining else readAppBufRemaining;
		contents.put( readAppBuf.array(), readAppBuf.position(), transfer );
		// advance the app buf by as much
		readAppBuf.position( readAppBuf.position() + transfer );
		// check if we're done
		if ( !readAppBuf.hasRemaining() ) {
			hasAppData = false;
			readAppBuf.clear();
		}
		return transfer;
	}
	
	shared DataNeeds handshake( variable SSLEngineResult.HandshakeStatus status ) {
		//HANDSHAKE:
		while ( true ) {
			if ( status == SSLEngineResult.HandshakeStatus.\iNOT_HANDSHAKING
				|| status == SSLEngineResult.HandshakeStatus.\iFINISHED )
			{
				return dataNeedsOk;
			}
			else if ( status == SSLEngineResult.HandshakeStatus.\iNEED_TASK ) {
				runTasks();
				status = sslEngine.handshakeStatus;
				continue;
			}
			else if ( status == SSLEngineResult.HandshakeStatus.\iNEED_UNWRAP ) {
				// read data
				//READ:
				while ( true ) {
					// if we have nothing in our net buffer or if it's not enough
					if ( !hasReadNetData && needMoreData ) {
						// read new or append to existing
						Integer read = channel.read( readNetBuf );
						if ( read == -1 ) {
							return dataNeedsEndOfFile;
						}
						if ( read == 0 ) {
							// no data to unwrap, must get some more
							return dataNeedsNeedsData;
						}
					}
					// put it in reading mode
					readNetBuf.flip();
					SSLEngineResult result = sslEngine.unwrap( readNetBuf, readAppBuf );
					value resultStatus = result.status;
					if ( resultStatus == SSLEngineResult.Status.\iBUFFER_OVERFLOW ) {
						return dataNeedsEndOfFile;
					}
					else if ( resultStatus == SSLEngineResult.Status.\iBUFFER_UNDERFLOW ) {
						if ( readNetBuf.hasRemaining() ) {
							// put what remains at the start as if we just read it
							readNetBuf.compact();
						}
						else{
							readNetBuf.clear();
						}
						// need to read more data, start over
						needMoreData = true;
					}
					else if ( resultStatus == SSLEngineResult.Status.\iCLOSED ) {
						return dataNeedsEndOfFile;
					}
					else if ( resultStatus == SSLEngineResult.Status.\iOK ) {
						if ( readNetBuf.hasRemaining() ) {
							// put what remains at the start as if we just read it
							readNetBuf.compact();
						}
						else {
							readNetBuf.clear();
						}
						needMoreData = false;
						// check the new handshake status
						status = result.handshakeStatus;
						// break of READ and continue on HANDSHAKE
						break;
					}
				}
			}
			else if ( status == SSLEngineResult.HandshakeStatus.\iNEED_WRAP ) {
				// we need to send data, not our own
				//WRITE:
				while ( true ) {
					// assume we are good to write
					variable value resultStatus = SSLEngineResult.Status.\iOK;
					// get something to write if we have nothing
					if ( !hasDataToWrite ) {
						SSLEngineResult result = sslEngine.wrap( emptyBuf, writeNetBuf );
						writeNetBuf.flip();
						resultStatus = result.status;
					}
					
					if ( resultStatus == SSLEngineResult.Status.\iBUFFER_OVERFLOW ) {
						// not enough space in the net buffer
						writeNetBuf = ByteBuffer.allocate( 2 * writeNetBuf.capacity() );
						continue;
					}
					else if ( resultStatus == SSLEngineResult.Status.\iBUFFER_UNDERFLOW ) {
						return dataNeedsEndOfFile;
					}
					else if ( resultStatus == SSLEngineResult.Status.\iCLOSED ) {
						return dataNeedsEndOfFile;
					}
					else if ( resultStatus == SSLEngineResult.Status.\iOK ) {
						// check the new handshake status
						while ( writeNetBuf.hasRemaining() ) {
							Integer written = channel.write( writeNetBuf );
							if ( written == -1 ) {
								return dataNeedsEndOfFile;
							}
							// we need to wait for further notification that we can write
							if ( written == 0 ) {
								hasDataToWrite = true;
								return dataNeedsNeedsData;
							}
						}
						writeNetBuf.clear();
						hasDataToWrite = false;
						status = sslEngine.handshakeStatus;
						// break WRITE and continue HANDSHAKE
						break;
					}
				}
			}
		}
	}
	
	
	void runTasks() {
		while ( exists task = sslEngine.delegatedTask ) {
			task.run();
		}
	}
	
}
