import 	std.stdio,
		std.concurrency,
		elevio,
		network;

private __gshared int current_floor;
private __gshared Dirn current_direction;

/*Move this to Orders.d (?)*/
struct State_vector{
	int floor;
	Dirn dir;
}

struct ConfirmedOrder{
	bool confirmed;
	alias confirmed this;	
}

int calculate_own_cost(Udp_msg msg){
	/** COST CALCULATING TABLE:
		-Add:
			*|Order_floor-Current_floor| +diff
			*Dir=! order_dir  +10
			*Fine +100
		-If tie, lowest ID wins, this a part of assoc_array and min value.
	**/
	int order_floor = msg.floor;
	int order_direction = msg.dir;

	int delta_floor=current_floor-order_floor;
	if(delta_floor<0){
		 delta_floor = -delta_floor;
	}
	int own_cost=0;
	own_cost+=delta_floor;
	if(current_direction != order_direction){
		own_cost+=10;
	}
	if(msg.fines){
		own_cost+=100;
	}
	return own_cost;
}

ubyte calculate_winner(int[ubyte] cost_list){ //Return ID of winner.
	return key_of_min_value(cost_list);
}


void bidding_main(int current_floor, Dirn current_direction, Tid order_list_thread){
	current_floor = current_floor;
	current_direction = current_direction;
	auto order_list = order_list_thread;

	while(true){
		receive(
			(Udp_msg msg){
				switch(msg.msgtype)
				{
					case 'e':
						if (msg.new_order){
							writeln("Received NEW message of type EXTERNAL from id ", msg.srcId);
							//TODO: Handle new orders, no one has bid on this yet
							//TODO: Calculate own bid and send
							Udp_msg new_message = msg;
							new_message.bid = calculate_own_cost(msg);
							new_message.new_order = 0;
							network.udp_send(new_message);
						}
						else {
							writeln("Received BID message from id ", msg.srcId);
							//TODO: handle someone has bid on this order
							//TODO: Add bid to cost_list
							//FOR TESTING ONLY; ASSUME ALL BIDS WINS
							bool win = true;
							if(win){
								auto btn = udp_msg_to_call(msg);
								order_list.send(btn);

							}

						}
						break;
					case 'i':
                        /*TODO: Send directly to orderqueue*/
                        writeln("Received message type INTERNAL from id ", msg.srcId);
						auto btn = udp_msg_to_call(msg);
						order_list.send(btn);
                        break;
					case 'c':
                        /*TODO: Handle confirmed orders, send to watchdog handler*/
                        writeln("Received message type CONFIRMED from id ", msg.srcId);
                        break;
					default:
                        /*TODO: Handle invalid message type*/
                        writeln("Invalid message type");
                        break;
				}
			},
			(State_vector state){
				current_floor = state.floor;
				current_direction = state.dir;
			}
			);
	}
}

ubyte key_of_min_value(int[ubyte] list){
	ulong min_val=429496729;
	ubyte min_key;
	foreach(key; list.keys){
		if(min_val>list[key]){
			min_val=list[key];
			min_key=key;
		}
	}
	return min_key;
}

void order_watchdog(CallButton order, int timeout_sec, Tid order_list_tid ){ //TODO: Define types for order and ID.
	import std.concurrency, std.datetime, std.conv;
	receiveTimeout((timeout_sec*1000).msecs,
		(ConfirmedOrder c){ 
			return;
		},	
	);
	order_list_tid.send(order);
	return;
}
