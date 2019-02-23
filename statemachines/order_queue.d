//Declaration of order_queue:
bool[string] order_queue;
//["0u","1u","2u","3d","2d","1d"]
import std.conv,
	std.stdio,
	std.typecons;

class order_list_element{
	order_list_element next;
	order_list_element prev;
	order_list_element start;
	string[] name_list;
	string name;
	private bool order_here;

	this(string name, string[] name_list){
	this.name=name;
	this.order_list=order_list.dup();
	}
	
	void insert_after(order_list_element newel){
		newel.next=this.next;
		newel.prev=this;
		next.prev=newel;
		this.next=newel;
	}

	void insert_before(order_list_element newel){
		newel.prev=this.prev;
		newel.next=this;
		prev.next=newel;
		this.prev=newel;
	}
	
	bool insert_sorted(Tuple!(int,bool) order_and_dir, bool value){
		auto element=new order_list_element(name,N);
		if(next is this){
			insert_after(element);
		}
		else{
			
		



		}

	}	


	const bool get_order_here(){
		return order_here;
	}
	void set_order_here(bool new_order){
		order_here=new_order;
	}

}


string[] order_queue_init( int number_of_floors){
	string[] queue;
	string id;
	foreach(floor; 0 .. number_of_floors-1){
		id=to!string(floor) ~"u";
		queue~=id;
	}
	for(int floor=number_of_floors; floor>1; floor-- ){
		id=to!string(floor) ~"d";
		queue~=id;
	}
	return queue;	
}


void main(){
	string[] names=order_queue_init(3);
//	writeln(names);
	auto first_elem= new order_list_element(null,null,names[0]);
	foreach(i;names[1..3]){
		new order_list_element(null,first_elem,i);
	}
	
	auto p=first_elem;
	foreach(i;1..100){
		writeln(p.name);
		p=p.next;
	}
}


