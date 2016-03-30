import herd.junc.net.data {
	TLSParameters,
	ClientAuth
}
import javax.net.ssl {
	SSLContext,
	TrustManager,
	TrustManagerFactory,
	KeyManagerFactory,
	KeyManager,
	SSLEngine,
	SSLParameters
}
import java.lang {
	ObjectArray
}
import java.security {
	KeyStore,
	SecureRandom
}
import java.io {
	FileInputStream
}
import ceylon.interop.java {

	javaString
}


"Initializes SSL engines by predefined TLS params."
throws( `class Throwable`, "Initialization parameters are invalid (unable to load file etc.)" )
by( "Lis" )
class SSLInitializer( TLSParameters tls ) {
	

	KeyStore? getKeyStore( String type, String storePath, String password ) {
		if ( storePath.empty ) {
			return null;
		}
		else {
			KeyStore keyStore = KeyStore.getInstance (
				type.empty then KeyStore.defaultType else type
			);
			if ( password.empty ) {
				keyStore.load( FileInputStream( storePath ), null );
			}
			else {
				keyStore.load( FileInputStream( storePath ), javaString( password ).toCharArray() );
			}
			return keyStore;
		}
	}


	ObjectArray<KeyManager>? getKeyManagers (
		KeyStore? keyStore, String keyManagerAlgorithm, String keyManagerPassword
	) {
		if ( exists keyStore ) {
			KeyManagerFactory kmf = KeyManagerFactory.getInstance (
				keyManagerAlgorithm.empty then KeyManagerFactory.defaultAlgorithm else keyManagerAlgorithm
			);
			if ( keyManagerPassword.empty ) {
				kmf.init( keyStore, null );
			}
			else {
				kmf.init( keyStore, javaString( keyManagerPassword ).toCharArray() );
			}
			return kmf.keyManagers;
		}
		else {
			return null;
		}
	}


	ObjectArray<TrustManager>? getTrustManagers (
		KeyStore? keyStore, String trustAlgorithm
	) {
		if ( exists keyStore ) {
			TrustManagerFactory tmf = TrustManagerFactory.getInstance (
				trustAlgorithm.empty then TrustManagerFactory.defaultAlgorithm else trustAlgorithm
			);
			tmf.init( keyStore );
			return tmf.trustManagers;
		}
		else {
			return dummyTrustManagers;
		}
	}


	"Creates new ssl context by `TLSParameters`."
	SSLContext createSSLContext() {
		// get stores
		KeyStore? keyStore = getKeyStore( tls.keyStoreType, tls.keyStorePath, tls.keyStorePassword );
		KeyStore? trustStore = getKeyStore( tls.trustStoreType, tls.trustStorePath, tls.trustStorePassword );
	
		ObjectArray<KeyManager>? keyManagers = getKeyManagers( keyStore, tls.keyManagerAlgorithm, tls.keyManagerPassword );
		ObjectArray<TrustManager>? trustManagers = getTrustManagers( trustStore, tls.trustAlgorithm );
	
		// initialize context and create ssl engine
		SSLContext sslContext = SSLContext.getInstance( tls.protocol.empty then "TLS" else tls.protocol );
		sslContext.init( keyManagers, trustManagers, SecureRandom() );
		return sslContext;
	}
	
	"SSL context used by initializer."
	SSLContext sslContext = createSSLContext();
	
	"`True` if key store is empty and supported ciphers to be used."
	Boolean useSupportedCiphers = tls.keyStorePath.empty;
	
	
	"Creates new SSL engine."
	shared SSLEngine createSSLEngine( String host, Integer port, Boolean clientMode ) {
		SSLEngine sslEngine = sslContext.createSSLEngine( host, port );
		
		sslEngine.useClientMode = clientMode;
		
		if ( useSupportedCiphers ) {
			// key manager is not specified - use supported ciphers
			SSLParameters sslParameters = sslEngine.sslParameters;
			sslParameters.cipherSuites = makeObjectArray (
				sslContext.supportedSSLParameters.cipherSuites.iterable.chain (
					sslParameters.cipherSuites.iterable
				).coalesced
			);
			
			if ( clientMode ) {
				// use HTTPS for client
				sslParameters.endpointIdentificationAlgorithm = "HTTPS";
			}
			else {
				// don't need authorization!
				switch ( tls.clientAuth )
				case ( ClientAuth.required | ClientAuth.requested ) {
					sslEngine.needClientAuth = false;
					sslEngine.wantClientAuth = true;
				}
				case ( ClientAuth.none ) {
					sslEngine.needClientAuth = false;
					sslEngine.wantClientAuth = false;
				}
			} 
			sslEngine.sslParameters = sslParameters;
		}
		else if ( !clientMode ) {
			// client authorization only in server mode
			switch ( tls.clientAuth )
			case ( ClientAuth.required ) {
				sslEngine.needClientAuth = true;
				sslEngine.wantClientAuth = true;
			}
			case ( ClientAuth.requested ) {
				sslEngine.needClientAuth = false;
				sslEngine.wantClientAuth = true;
			}
			case ( ClientAuth.none ) {
				sslEngine.needClientAuth = false;
				sslEngine.wantClientAuth = false;
			}
		}
		return sslEngine;
	}
	
}
