import herd.junc.api.monitor {

	Meter
}


"Instrumenting sockets."
by( "Lis" )
interface SocketMetric {
	shared formal void bytesSend( Integer bytes );
	shared formal void sendError();
	shared formal void bytesReceived( Integer bytes );
	shared formal void receiveError();
	
}

"Real sockets metric."
by( "Lis" )
class SocketMetricReal (
	Meter bytesSendMeter,
	Meter errorSendMeter,
	Meter bytesReceivedMeter,
	Meter errorReceivedMeter
)
	satisfies SocketMetric
{
	shared actual void bytesSend( Integer bytes ) => bytesSendMeter.tick( bytes );
	shared actual void sendError() => errorSendMeter.tick();
	shared actual void bytesReceived( Integer bytes ) => bytesReceivedMeter.tick( bytes );
	shared actual void receiveError() => errorReceivedMeter.tick();
}

"Empty sockets metric."
by( "Lis" )
object emptySocketMetric satisfies SocketMetric
{
	shared actual void bytesReceived(Integer bytes) {}
	shared actual void bytesSend(Integer bytes) {}
	shared actual void receiveError() {}
	shared actual void sendError() {}
}
