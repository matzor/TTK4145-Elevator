import
	std.stdio,
	std.concurrency,
	std.conv,
	std.datetime,
	elevio,
	network,
	network_peers,
	main;

private __gshared int current_floor;
private __gshared Dirn current_direction;
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
	return current_floor;
}

void bidding_main(int current_floor, Dirn current_direction, Tid order_list_thread) {
	// Wait for thread list
	Tid[ThreadName] threads;
	receive((shared(Tid[ThreadName]) t) {threads = cast(Tid[ThreadName])t;});
	writeln("List received! " ~ to!string(threads));

	current_floor = current_floor;
	current_direction = current_direction;
	order_list_tid = order_list_thread;

	while(true) {
		receive(
			(Udp_msg msg) {
				switch(msg.msgtype) {
				case 'e':
					if (msg.new_order) {
						writeln("Received NEW message of type EXTERNAL from id ", msg.srcId);
						handle_new_auction(msg);
					} else {
						writeln("Received BID message from id ", msg.srcId);
						handle_bid(msg);
					}
					break;
				case 'i':
					writeln("Received message type INTERNAL from id ", msg.srcId);
					auto btn = udp_msg_to_call(msg);
					order_list_tid.send(btn);
					break;
				case 'c':
					/*TODO: Handle confirmed orders, send to watchdog handler*/
					writeln("Received message type CONFIRMED from id ", msg.srcId);
					handle_completed_command(msg);
					break;
				default:
					// Log and ignore invalid message types
					writeln("Invalid message type");
					break;
				}
			},
			(State_vector state) {
				current_floor = state.floor;
				current_direction = state.dir;
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
	bool was_interrupted = false;
	receiveTimeout( (1000*1).msecs, // 1-second timeout
		(AuctionCompleteMsg msg) {
			writeln("  auction watchdog killed");
			was_interrupted = true;
		},
	);
	if (was_interrupted) {
		writeln("  auction watchdog triggered");
		ownerTid.send(BidTimeoutMsg(order));
	}
}

void handle_new_auction(Udp_msg msg) {
	CallButton order = udp_msg_to_call(msg);
	// only one auction per call button
	writeln("  finding auction...");
	OrderAuction auction = get_auction(order);
	if (auction !is null) {
		writeln("  auction already running. Ignoring...");
		return;
	}
	writeln("  no auction for order; creating new...");
	// init auction
	auction = new OrderAuction();
	auction.our_bid = calculate_own_cost(order);
	auction.bid_count = 1;
	auction.this_elevator_is_winning = true;
	// setup auction timeout
	writeln("  spawning watchdog");
	auction.timeout_thread = spawn(&auction_watchdog, order);
	writeln("  watchdog spawned");
	// add to auction list
	writeln("  adding auction to auction list");
	auctions[order] = auction;
	check_bidding_complete(order);
}

void handle_bid(Udp_msg msg) {
	// Look up in auction list
	CallButton order = udp_msg_to_call(msg);
	OrderAuction auction = get_auction(order);
	if (auction is null) {
		return;
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
		complete_auction(order);
	}
}

void complete_auction(CallButton order) {
	OrderAuction auction = get_auction(order);
	// Register order if auction was won
	if (auction.this_elevator_is_winning) {
		writeln("  THIS ELEVATOR WON!!");
		order_list_tid.send(order);
	}
	// Setup watchdog
	auction.timeout_thread = spawn(&order_watchdog, order, 30);
}

void handle_completed_command(Udp_msg msg) {
	writeln("  handling COMPLETED order");
	CallButton order = udp_msg_to_call(msg);
	writeln("  bluh!");
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
