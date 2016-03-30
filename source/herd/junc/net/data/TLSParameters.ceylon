
"Defines SSL/TLS parameters."
see( `value NetAddress.tls` )
by( "Lis" )
shared class TLSParameters (
	"SSL/TLS protocol." shared String protocol = "TLS",
	"Type of key store." shared String keyStoreType = "",
	"Path to key store file." shared String keyStorePath = "",
	"Password of key store." shared String keyStorePassword = "",
	"Key manager algorithm." shared String keyManagerAlgorithm = "",
	"Key manager password." shared String keyManagerPassword = "",
	"Type of trust store." shared String trustStoreType = "",
	"Path to trust store file." shared String trustStorePath = "",
	"Password of trust store." shared String trustStorePassword = "",
	"Trust manager algorithm." shared String trustAlgorithm = "",
	"Type of client authorization." shared ClientAuth clientAuth = ClientAuth.required
) {}
