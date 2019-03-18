import std.array,std.range;
import std.stdio;
import std.concurrency;
import elevio;


enum HallCall : int {
    up,
    down
}

struct MotorDirUpdate {
	Dirn dir;
	alias dir this;
}

struct NewOrderRequest {
	int floor;
	CallButton.Call call;
}

struct TargetFloor {
	int floor;
	alias floor this;
}

class OrderList {
	class Order{
		public int floor;
		public CallButton.Call call;
		public bool order_here;
		public bool cab_here;
		public Order next;
		this(int floor, CallButton.Call call){
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
		do{
			if (floor==iter.floor) {
				if (call == CallButton.Call.cab) return iter;
				if (call == iter.call) return iter;
			}
			iter = iter.next;
		}while (iter != next_stop); 
		return null;
	}
	
	int get_next_order_floor(){
		Order iter = next_stop;
		do{
			if (iter.order_here || iter.cab_here) {
				return iter.floor;
			}
			iter = iter.next;
		}while (iter != next_stop);
		return -1;
	}

	void set_order(int floor, CallButton.Call call) {
		Order order = get_order(floor, call);
		if (call == CallButton.Call.cab) {
			order.cab_here = true;
		} else {
			order.order_here = true;
		}
	}
	
	void finish_order (int floor, CallButton.Call call) {
		Order order = get_order(floor, call);
		order.cab_here = false;
		order.order_here = false;
		next_stop = next_stop.next;
	}
	
	this(int numfloors,int start_floor) {
		o_list = order_queue_init(numfloors);
		next_stop=o_list[start_floor];	
	}
	private Order[] order_queue_init(int number_of_floors){
		Order[] queue;
	
		foreach(floor; 0 .. number_of_floors-1){
			queue~=new Order(floor, CallButton.Call.hallUp);
		}
		for(int floor=number_of_floors; floor>1; floor-- ){
	 		queue~=new Order(floor, CallButton.Call.hallDown);
		}
		for (int i=0; i<queue.length-1; i++) {
			queue[i].next = queue[i+1];
		}
		queue.back.next = queue[0];
		return queue; 
	}
}

void run_order_list (int numfloors, int startfloor, Tid movement_thread) {
	auto orderlist = new OrderList(numfloors, startfloor);
	int floor = startfloor;
	Dirn motor_dir = Dirn.up;
	while(1) {
		receive(
			(FloorSensor f) {
				floor = f;
				CallButton.Call dir_to_calldir;
				switch(motor_dir){
					case(Dirn.up):
						dir_to_calldir=CallButton.Call.hallUp;
						break;	
					case(Dirn.down):
						dir_to_calldir=CallButton.Call.hallDown;
						break;
					default:
						//nothing happen
						break;
				}
						

				orderlist.finish_order(floor, dir_to_calldir);
				movement_thread.send(TargetFloor(orderlist.get_next_order_floor()));
			},
			(MotorDirUpdate m) {
				motor_dir = m;
			},
			(CallButton n) {
				orderlist.set_order(n.floor, n.call);
				movement_thread.send(TargetFloor(orderlist.get_next_order_floor()));
			},
		);
	}
}

