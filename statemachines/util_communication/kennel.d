bool order_watchdog(int ID, int order){ //TODO: Define types for order and ID.
	import std.concurrency;
	import std.datetime;
	bool answer;
	Duration interval =10.msecs; 
	while(true){
		receiveTimeout(interval,
			(bool ack){ answer=ack;},
			(Variant rest){
				import std.string;
				throw(new StringException("Whatchdog recieved invalid type of message."));
			}
		);
		if(answer==true){
			return true; //If confirmed order, die silently. 
		}
		udp_send_safe(order, thisTid);
		receiveTimeout(
			
		);
		//TODO: Send order (Aka do a bid) again, with fine attached.
		//TODO: Listen for ack. If noone took the order, that is: if udp says "no ack" =>  Start function over again.
		//TODO: If someone took the order: die.
		//TODO: Is internal and external different now?
	}
}
