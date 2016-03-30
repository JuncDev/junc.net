import ceylon.test {

	testExecutor
}
import herd.asynctest {

	AsyncTestExecutor
}


testExecutor( `class AsyncTestExecutor` )
native("jvm")
module test.herd.junc.net "0.1.0" {
	shared import herd.junc.api "0.1.0";
	shared import herd.junc.net.station "0.1.0";
	shared import herd.junc.core "0.1.0";
	shared import herd.junc.net.data "0.1.0";
	shared import herd.asynctest "0.5.1";
	import ceylon.collection "1.2.2";
	import ceylon.test "1.2.2";
}
