import
	std.array,
	std.range,
	std.stdio,
	std.conv,
	std.concurrency;
		
import
	elevio,
	main,
	network,
	log_file;

private Tid[ThreadName] threads;

struct MotorDirUpdate {
	Dirn dir;
	alias dir this;
}

struct TargetFloor {
	int floor;
	alias floor this;
}

struct AlreadyOnFloor { 
	int floor;
	alias floor this;
}

class OrderList {
	public class Order {
		public int floor;
		public CallButton.Call call;
		public bool order_here;
		public bool cab_here;
		public Order next;
		this(int floor, CallButton.Call call) {
			this.floor = floor;
			this.call = call;
			this.order_here=0;
			this.cab_here=0;
		}
	}
	private Order[] o_list;
	private Order next_stop;

	private Order get_order(int floor, CallButton.Call call) {
		Order iter = next_stop;
		do {
			if (floor==iter.floor) {
				if (call == CallButton.Call.cab) return iter;
				if (call == iter.call) return iter;
			}
			iter = iter.next;
		} while (iter != next_stop);
		return null;
	}

	int get_next_order_floor() {
		Order iter = next_stop;
		do {
			if (iter.order_here || iter.cab_here) {
				return iter.floor;
			}
			iter = iter.next;
		} while (iter != next_stop);
		return -1;
	}

	bool set_order(int floor, CallButton.Call call) {
		Order order = get_order(floor, call);
		if(call == CallButton.Call.cab) {
			if(order.cab_here){return 0;}
		} else {
			if(order.order_here){return 0;}
		}
		log_set_floor(floor, call);
		callButtonLight(floor, call, 1);
		if (call == CallButton.Call.cab) {
			order.cab_here = true;
		} else {
			order.order_here = true;
		}
		return 1;
	}

	void finish_order (CallButton btn) {
		CallButton.Call call = btn.call;
		int floor = btn.floor;
		Order order = get_order(floor, call);
		callButtonLight(floor, call, 0);
		callButtonLight(floor, CallButton.Call.cab, 0);
		order.cab_here = false;
		order.order_here = false;
		next_stop = next_stop.next;
		log_clear_floor(floor, call);
		log_clear_floor(floor, CallButton.Call.cab);

		threads[ThreadName.network].send(Finished_order(btn));
	}

	this(int numfloors,int start_floor) {
		o_list = order_queue_init(numfloors);
		next_stop=o_list[start_floor];
	}
	private Order[] order_queue_init(int number_of_floors) {
		Order[] queue;

		foreach(floor; 0 .. number_of_floors) {
			queue~=new Order(floor, CallButton.Call.hallUp);
		}
		for(int floor=number_of_floors-1; floor>=0; floor-- ) {
	 		queue~=new Order(floor, CallButton.Call.hallDown);
		}
		for (int i=0; i<queue.length-1; i++) {
			queue[i].next = queue[i+1];
		}
		queue.back.next = queue[0];
		return queue;
	}
	void printout() {
		Order iter = next_stop;
		do {
			writeln("Floor: ", iter.floor, ", dir: ", iter.call,", order: ", iter.order_here, ", cab: ", iter.cab_here);

			iter = iter.next;
		} while (iter != next_stop);
	}
}

CallButton.Call dirn_to_call(Dirn dir) {
	if(dir == Dirn.up) {
		return CallButton.Call.hallUp;
	} else {
		return CallButton.Call.hallDown;
	}
}

void run_order_list (int numfloors, int startfloor) {
	// Wait for thread list
	receive((shared(Tid[ThreadName]) t) {threads = cast(Tid[ThreadName])t;});
	writeln("List received! " ~ to!string(threads));
	Tid movement_thread = threads[ThreadName.movement];

	auto orderlist = new OrderList(numfloors, startfloor);
	init_log(numfloors);
	int[] log=read_log();
	for (int i=0; i < numfloors; i++) {
		for (int j = 0; j < 3; j++) {
			if(log[numfloors*j + i]) {
				switch(j){
				case 0:
					orderlist.set_order(i, CallButton.Call.cab);
					break;
				case 1:
					orderlist.set_order(i, CallButton.Call.hallUp);
					break;
				case 2:
					orderlist.set_order(i, CallButton.Call.hallDown);
					break;
				default:
					break;
				}
			}
		}
	}
	int floor = startfloor;
	Dirn motor_dir = Dirn.down;

	while(1) {
		receive(
			(FloorSensor f) {
				floor = f;
				CallButton.Call dir_to_calldir = dirn_to_call(motor_dir);
				CallButton btn = CallButton(floor, dir_to_calldir);
				orderlist.finish_order(btn);
				if(
					orderlist.get_next_order_floor == floor
					|| floor == 0
					|| floor == numfloors-1
				){
					if(dir_to_calldir==CallButton.Call.hallUp) {
						dir_to_calldir=CallButton.Call.hallDown;
					} else {
						dir_to_calldir=CallButton.Call.hallUp;
					}
					orderlist.finish_order(btn);
				}
				movement_thread.send(TargetFloor(orderlist.get_next_order_floor()));
			},
			(MotorDirUpdate m) {
				motor_dir = m;
			},
			(CallButton n) {
				if(orderlist.set_order(n.floor, n.call)) {
					int next_order_floor = orderlist.get_next_order_floor();
					writeln("target: ", n.floor, " Current: ", floor);
					if(next_order_floor != -1) {
						floor=-1;
					}
					movement_thread.send(TargetFloor(next_order_floor));
				}
			},
			(AlreadyOnFloor a) {
				orderlist.finish_order(CallButton(a, CallButton.Call.hallUp));
				orderlist.finish_order(CallButton(a, CallButton.Call.hallDown));
				//movement_thread.send(TargetFloor(orderlist.get_next_order_floor()));
			},
			(Obstruction a) {
				orderlist.printout();
			},
		);
	}
}
