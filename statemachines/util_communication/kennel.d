void order_watchdog(CallButton order, int timeout_sec, Tid order_list_tid ){ //TODO: Define types for order and ID.
	import std.concurrency, std.datetime, std.conv;
	udp_send_safe(order, thisTid);
	receiveTimeout((timeout_sec*1000).msecs,
		(ConfirmedOrder c){ 
			return;
		},	
	);
	order_list_tid.send(order);
	return;
}
