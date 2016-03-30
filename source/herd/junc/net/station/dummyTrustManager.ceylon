import java.lang {
	ObjectArray
}
import javax.net.ssl {
	TrustManager,
	X509TrustManager
}
import java.security.cert {
	X509Certificate
}


"Trust all."
object dummyTrustManager satisfies X509TrustManager {
	
	shared actual ObjectArray<X509Certificate> acceptedIssuers 
			=> ObjectArray<X509Certificate>( 0 );
	
	shared actual void checkClientTrusted( ObjectArray<X509Certificate> chain, String authType ) 
	{}
	
	shared actual void checkServerTrusted( ObjectArray<X509Certificate> chain, String authType ) 
	{}
}

"Generates java aaray."
ObjectArray<Type> makeObjectArray<Type>( {Type*} items )
		given Type satisfies Object
{
	value seq = items.sequence();
	value ret = ObjectArray<Type>( seq.size );
	variable Integer i = 0;
	for ( item in seq ) {
		ret.set( i ++, item );
	}
	return ret;
}

"Trust all."
ObjectArray<TrustManager> dummyTrustManagers 
		= makeObjectArray<TrustManager>{dummyTrustManager};
