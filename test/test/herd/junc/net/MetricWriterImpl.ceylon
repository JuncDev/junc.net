import herd.junc.api.monitor {

	AverageMetric,
	monitored,
	CounterMetric,
	MeterMetric,
	MetricWriter,
	MetricSet
}
import ceylon.collection {

	ArrayList
}


class MetricWriterImpl() satisfies MetricWriter {
	
	shared actual void writeMetric( MetricSet metrics ) {
		variable CounterMetric? sockets = null;
		variable CounterMetric? threads = null;
		variable AverageMetric? response = null;
		variable AverageMetric? server = null;
		ArrayList<Float> loads = ArrayList<Float>(); 
		//variable AverageMetric? load = null;
		//variable AverageMetric? queue = null;
		variable MeterMetric? messages = null;
		
		for ( c in metrics.counters ) {
			if ( c.name == "socketsNumber" ) { sockets = c; }
			if ( c.name == monitored.numberOfThreads ) { threads = c; }
		}
		for ( a in metrics.averages ) {
			if ( a.name == "responseRate" ) { response = a; }
			if ( a.name == "serverRate" ) { server = a; }
			if ( a.name.endsWith( monitored.threadLoadLevel ) ) { loads.add( a.measure() ); }
			//if ( a.name.endsWith( monitored.threadQueuePerLoop ) ) { queue = a; }
		}
		for ( m in metrics.meters ) {
			if ( m.name == "messageRate" ) { messages = m; }
		}
		
		if ( exists c = sockets, exists a = response, exists aS = server, exists mM = messages,
			exists cT = threads )
		{
			variable String load = "";
			for ( l in loads ) { load += formatFloat( l, 2, 2 ) + ", "; }
			print (
				"socket number = ``c.measure()``, response rate = ``a.measure()``, server rate = ``aS.measure()``, "
				+ "message rate = ``mM.measure()``, threads = ``cT.measure()``, load = ``load``"
			);
		}
	}
	
}
