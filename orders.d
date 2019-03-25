import std.array,std.range;
import std.stdio;
import std.concurrency;
import elevio, log_file;

struct MotorDirUpdate {
	Dirn dir;
	alias dir this;
}

struct InitTid {
	Tid thread_id;
	alias thread_id this;
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
		log_set_floor(floor, call);
		callButtonLight(floor, call, 1);
		if (call == CallButton.Call.cab) {
			order.cab_here = true;
		} else {
			order.order_here = true;
		}
	}

	void finish_order (int floor, CallButton.Call call) {
		Order order = get_order(floor, call);
		callButtonLight(floor, call, 0);
		callButtonLight(floor, CallButton.Call.cab, 0);
		order.cab_here = false;
		order.order_here = false;
		next_stop = next_stop.next;
		log_clear_floor(floor, call);
		log_clear_floor(floor, CallButton.Call.cab);
		/*TODO: Give ordermanager Network thread id
		Finished_order order;
		order.floor = floor;
		order.call = call;
		network_tid.send(order);
		*/
	}

	this(int numfloors,int start_floor) {
		o_list = order_queue_init(numfloors);
		next_stop=o_list[start_floor];
	}
	private Order[] order_queue_init(int number_of_floors){
		Order[] queue;

		foreach(floor; 0 .. number_of_floors){
			queue~=new Order(floor, CallButton.Call.hallUp);
		}
		for(int floor=number_of_floors-1; floor>=0; floor-- ){
	 		queue~=new Order(floor, CallButton.Call.hallDown);
		}
		for (int i=0; i<queue.length-1; i++) {
			queue[i].next = queue[i+1];
		}
		queue.back.next = queue[0];
		return queue;
	}
	void printout(){
		Order iter = next_stop;
		do{
			writeln("Floor: ", iter.floor, ", dir: ", iter.call,", order: ", iter.order_here, ", cab: ", iter.cab_here);

			iter = iter.next;
		}while (iter != next_stop);
	}
}

CallButton.Call dirn_to_call(Dirn dir){
	if(dir==Dirn.up){
		return CallButton.Call.hallUp;
	}
	else{
		return CallButton.Call.hallDown;
	}

}

void run_order_list (int numfloors, int startfloor) {
	auto orderlist = new OrderList(numfloors, startfloor);
	init_log(numfloors);
	int[] log=read_log();
	for (int i=0; i < numfloors; i++){
		for (int j = 0; j < 3; j++){
			if(log[numfloors*j + i]){
				switch(j){
					case 0:
						orderlist.set_order(i,CallButton.Call.cab);
						break;
					case 1:
						orderlist.set_order(i,CallButton.Call.hallUp);
						break;
					case 2:
						orderlist.set_order(i,CallButton.Call.hallDown);
						break;
					default:
						break;
				}

			}
		}
	}
	int floor = startfloor;
	Dirn motor_dir = Dirn.down;

	Tid movement_thread = receiveOnly!InitTid;
	movement_thread.send(InitTid(thisTid));
	while(1) {
		receive(
			(FloorSensor f) {
				floor = f;
				CallButton.Call dir_to_calldir=dirn_to_call(motor_dir);
				orderlist.finish_order(floor, dir_to_calldir);
				if(orderlist.get_next_order_floor == floor){
					if(dir_to_calldir==CallButton.Call.hallUp){
						dir_to_calldir=CallButton.Call.hallDown;
					}
					else{
						dir_to_calldir=CallButton.Call.hallUp;
					}
					orderlist.finish_order(floor, dir_to_calldir);
				}
				movement_thread.send(TargetFloor(orderlist.get_next_order_floor()));
			},
			(MotorDirUpdate m) {
				motor_dir = m;
			},
			(CallButton n) {
				if(n.floor==floor){
					//writeln("Already here");
				}
				else{
					orderlist.set_order(n.floor, n.call);
				}
				movement_thread.send(TargetFloor(orderlist.get_next_order_floor()));
			},
			(Obstruction a){
				orderlist.printout();
			},
		);
	}
}
