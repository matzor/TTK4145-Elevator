import 	elevio,
		network;

private __gshared int current_floor;
private __gshared Dirn current_direction;

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
	import	assoc_array_helper;
	return key_of_min_value(cost_list);
}

void bidding_main(int current_floor, Dirn current_direction){
	current_floor = current_floor;
	current_direction = current_direction;

	while(true){
		receive(
			(Udp_msg msg){
				switch(msg.msgtype)
				{
					case 'e':
				  		writeln("Received message type EXTERNAL from id ", msg.srcId);
						if (msg.new_order){
							//TODO: Handle new orders, no one has bid on this yet
							//TODO: Calculate own bid and send
							Udp_msg new_message = msg;
							new_message.bid = calculate_own_cost(msg);
							mew_message.new_order = 0;
							network.udp_send(new_message);
						}
						else {
							//TODO: handle someone has bid on this order
							//TODO: Add bid to cost_list
						}
						break;
					case 'i':
                        /*TODO: Send directly to orderqueue*/
                        writeln("Received message type INTERNAL from id ", msg.srcId);
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
