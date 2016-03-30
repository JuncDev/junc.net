import herd.junc.api {
	JuncSocket
}


"Narrowing _junc socket_ to _net socket_."
shared alias NetSocket => JuncSocket<Byte[], Byte[]>;
