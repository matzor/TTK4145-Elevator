import
	std.stdio,
	std.concurrency,
	std.conv,
	std.datetime,
	elevio,
	network,
	network_peers;

private __gshared int current_floor;
private __gshared Dirn current_direction;
private __gshared OrderAuction[CallButton] auctions;
private __gshared int peer_count;
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

OrderAuction retrieve_auction_from_list (CallButton order) {
	return auctions[order];
}

void auction_watchdog(CallButton order) {
	writeln("  auction watchdog started");
	receiveTimeout( (1000*1).msecs, // 1-second timeout
		(AuctionCompleteMsg msg) {
			return;
		},
	);
	ownerTid.send(BidTimeoutMsg(order));
}

void handle_new_auction(Udp_msg msg) {
	CallButton order = udp_msg_to_call(msg);
	// only one auction per call button
	OrderAuction auction = retrieve_auction_from_list(order);
	if (auction !is null) return;
	// init auction
	auction = new OrderAuction();
	auction.our_bid = calculate_own_cost(order);
	auction.bid_count = 1;
	auction.this_elevator_is_winning = false;
	// setup auction timeout
	auction.timeout_thread = spawn(&auction_watchdog, order);
	// add to auction list
	auctions[order] = auction;
}

void handle_bid(Udp_msg msg) {
	// Look up in auction list
	CallButton order = udp_msg_to_call(msg);
	OrderAuction auction = retrieve_auction_from_list(order);
	if (auction is null) {
		return;
	}
	// Check bid against ours
	if (auction.our_bid > msg.bid) {
		auction.this_elevator_is_winning = false;
	}
	// Is bidding complete?	
	if (auction.bid_count >= peer_count) {
		auction.timeout_thread.send(AuctionCompleteMsg());
		complete_auction(order);
	}
}

void complete_auction(CallButton order) {
	OrderAuction auction = retrieve_auction_from_list(order);
	// Register order if auction was won
	if (auction.this_elevator_is_winning) {
		order_list_tid.send(order);
	}
	// Setup watchdog
	auction.timeout_thread = spawn(&order_watchdog, order, 30);
}

void handle_completed_command(Udp_msg msg) {
	CallButton order = udp_msg_to_call(msg);
	auctions[order].timeout_thread.send(OrderConfirmedMsg());
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
