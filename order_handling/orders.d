import std.array,std.range;
import std.stdio;
class OrderList {

	enum Direction {
		Up,
		Down,
		Cab,
	}
	
	class Order{
		public int floor;
		public Direction dir;
		public bool order_here;
		public bool cab_here;
		public Order next;
		this(int floor, Direction dir){
			this.floor = floor;
			this.dir = dir;
			this.order_here=0;
			this.cab_here=0;
		}
	}
	Order[] o_list;
	Order next_stop;

	Order get_order(int floor, Direction dir) {
		Order iter = next_stop;
		do{
			if (floor==iter.floor) {
				if (dir == Direction.Cab) return iter;
				if (dir == iter.dir) return iter;
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

	void set_order(int floor, Direction dir) {
		Order order = get_order(floor, dir);
		if (dir == Direction.Cab) {
			order.cab_here = true;
		} else {
			order.order_here = true;
		}
	}
	
	void finish_order (int floor, Direction dir) {
		Order order = get_order(floor, dir);
		order.cab_here = false;
		order.order_here = false;
		next_stop = next_stop.next;
	}
	
	this(int numfloors) {
		o_list = order_queue_init(numfloors);
	}
	Order[] order_queue_init(int number_of_floors){
		Order[] queue;
	
		foreach(floor; 0 .. number_of_floors-1){
			queue~=new Order(floor, Direction.Up);
		}
		for(int floor=number_of_floors; floor>1; floor-- ){
	 		queue~=new Order(floor, Direction.Down);
		}
		for (int i=0; i<queue.length-1; i++) {
			queue[i].next = queue[i+1];
		}
		queue.back.next = queue[0];
		next_stop=queue[0]; //TODO: where to start elevator?
		return queue; 
	}
}

void main(){
	import std.stdio;
	auto test= new OrderList(11);
	test.set_order(4,test.Direction.Down);
	test.set_order(9,test.Direction.Up);
	test.set_order(2,test.Direction.Cab);
	test.set_order(2,test.Direction.Down);
	test.set_order(3,test.Direction.Down);
	int c_floor;
	while(1){
		c_floor=test.get_next_order_floor();
		writeln(c_floor);
		if(c_floor==-1){
			break;
		}
		test.finish_order(c_floor,test.Direction.Up);
		test.finish_order(c_floor,test.Direction.Down);
	}	
}
