import
	std.stdio,
	std.concurrency,
	std.conv,
	std.datetime,
	elevio,
	network,
	network_peers,
	main;

private __gshared State_vector states;
private __gshared OrderAuction[CallButton] auctions;
private __gshared int peer_count;
private __gshared Tid[ThreadName] threads;
private __gshared Tid order_list_tid;

/*Move this to Orders.d (?)*/
struct State_vector {
	int floor;
	Dirn dir;
}

class OrderAuction {
	int our_bid;
	int bid_count = 1;
	bool this_elevator_is_winning = true;
	Tid timeout_thread;
}

// Elevator watchdog
struct OrderTimeoutMsg {CallButton order;}
struct OrderConfirmedMsg {}

// Auction watchdog
struct BidTimeoutMsg {CallButton order;}
struct AuctionCompleteMsg {}

int calculate_own_cost(CallButton order) {
	// TODO: implement
	int own_cost;
	int delta_floor = states.floor - order.floor;
	int abs_delta_floor = delta_floor;
	if (delta_floor < 0)	{abs_delta_floor = -delta_floor;}
	own_cost += abs_delta_floor;
	Dirn order_dir;
	if (order.call == CallButton.Call.hallUp){order_dir = Dirn.up;}
	else if (order.call == CallButton.Call.hallDown){order_dir = Dirn.down;}
	else order_dir = Dirn.stop;

	if(states.dir != order_dir){
		own_cost += 10;
	}
	if((states.dir == Dirn.stop) && (delta_floor == 0)){own_cost = 0;}
	writeln("----------------CALCULATED OWN COST: ", own_cost);
	return own_cost;
}

void bidding_main(int current_floor, Dirn current_direction, Tid order_list_thread) {
	// Wait for thread list
	Tid[ThreadName] threads;
	receive((shared(Tid[ThreadName]) t) {threads = cast(Tid[ThreadName])t;});
	writeln("List received! " ~ to!string(threads));
	states.floor = current_floor;
	states.dir = current_direction;
	order_list_tid = order_list_thread;

	while(true) {
		receive(
			(Udp_msg msg) {
				switch(msg.msgtype) {
				case 'e':
					if (msg.new_order) {
						writeln("Received NEW message of type EXTERNAL from id ", msg.srcId, " Floor ", msg.floor);
						handle_new_auction(msg);
					} else {
						writeln("Received BID message from id ", msg.srcId, ", Floor ", msg.floor, ", Bid ", msg.bid);
						handle_bid(msg);
					}
					break;
				case 'i':
					writeln("Received message type INTERNAL from id ", msg.srcId);
					auto btn = udp_msg_to_call(msg);
					order_list_tid.send(btn);
					break;
				case 'c':
					/*TODO: Handle completed orders, send to watchdog handler*/
					writeln("Received message type COMPLETED from id ", msg.srcId, ", Floor ", msg.floor);
					handle_completed_command(msg);
					break;
				default:
					// Log and ignore invalid message types
					writeln("Invalid message type");
					break;
				}
			},
			(State_vector state) {
				states = state;
			},
			(PeerList p) {
				peer_count = to!int(p.length);
			},
			(BidTimeoutMsg msg) {
				complete_auction(msg.order);
			},
		);
	}
}

OrderAuction get_auction (CallButton order) {
	return auctions.get(order, null);
}

void auction_watchdog(CallButton order) {
	writeln("  auction watchdog started");
	receiveTimeout( (1000*2).msecs, // 2-second timeout
		(AuctionCompleteMsg msg) {
			writeln("  auction watchdog killed");
			return;
		},
	);
	writeln("  auction watchdog triggered: ");
	ownerTid.send(BidTimeoutMsg(order));
}

void handle_new_auction(Udp_msg msg) {
	CallButton order = udp_msg_to_call(msg);
	// only one auction per call button
	writeln("  finding auction...");
	OrderAuction auction = get_auction(order);
	if (auction !is null) {
		writeln("  auction already running. Ignoring...");
		order.floor=-1;
		return;
	}
	writeln("  no auction for order; creating new...");
	// init auction
	auction = new OrderAuction();
	auto our_bid = calculate_own_cost(order);
	auction.our_bid = our_bid;
	auction.bid_count = 1;
	auction.this_elevator_is_winning = true;

	// setup auction timeout --- moved to owner function
	writeln("  spawning watchdog");
	auction.timeout_thread = spawn(&auction_watchdog, order);
	writeln("  watchdog spawned");
	// add to auction list
	writeln("  adding auction to auction list");
	auctions[order] = auction;

	// get network thread and send, dont use that send function
	Udp_msg bid_msg = msg;
	bid_msg.bid = our_bid;
	bid_msg.msgtype = 'e';
	bid_msg.new_order = 0;
	udp_send(bid_msg);

	check_bidding_complete(order);
}

void handle_bid(Udp_msg msg) {
	// Look up in auction list
	CallButton order = udp_msg_to_call(msg);
	OrderAuction auction = get_auction(order);
	if (auction is null) {
		return;
	}
	if(msg.srcId != id()){
		auction.bid_count += 1;
	}
	// Check bid against ours
	if (auction.our_bid > msg.bid) {
		auction.this_elevator_is_winning = false;
	}
	check_bidding_complete(order);
}

void check_bidding_complete(CallButton order) {
	OrderAuction auction = get_auction(order);
	writeln("  checking if bidding is complete. peer_count=" ~ to!string(peer_count) ~ ", bid_count=" ~ to!string(auction.bid_count));
	if (auction.bid_count >= peer_count) {
		auction.timeout_thread.send(AuctionCompleteMsg());
		try{
			complete_auction(order);
		} catch(Exception e ){ writeln("Race condition");}
	}
}

void complete_auction(CallButton order) {
	OrderAuction auction = get_auction(order);
	// Register order if auction was won
	if (auction.this_elevator_is_winning) {
		writeln("  THIS ELEVATOR WON!!");
		order_list_tid.send(order);
	}
	else{writeln("  THIS ELEVATOR LOST! :(");}
	// Setup watchdog
	auction.timeout_thread = spawn(&order_watchdog, order, 30);
}

void handle_completed_command(Udp_msg msg) {
	writeln("  handling COMPLETED order");
	CallButton order = udp_msg_to_call(msg);
	OrderAuction auction = get_auction(order);

	if (auction is null) {
		writeln("  not auctioned order. Ignoring...");
		return;
	}
	auction.timeout_thread.send(OrderConfirmedMsg());
	cleanup_auction(order);
}

void order_watchdog(CallButton order, int timeout_sec) {
	receiveTimeout((timeout_sec*1000).msecs,
		(OrderConfirmedMsg c) {
			return;
		},
	);
	ownerTid.send(OrderTimeoutMsg(order));
	return;
}

void cleanup_auction(CallButton order) {
	auctions.remove(order);
}
