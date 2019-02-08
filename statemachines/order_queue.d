//Declaration of order_queue:
//bool[string] order_queue;
//["0u","1u","2u","3d","2d","1d"]
import std.conv;
import std.stdio;

//TODO: probably make this a linked ring list
bool[string] order_queue_init( int number_of_floors){
	static bool[string] queue;
	string id;
	foreach(floor; 0 .. number_of_floors-1){
		id=to!string(floor) ~"u";
		queue[id]=0;
	}
	for(int floor=number_of_floors; floor>1; floor-- ){
		id=to!string(floor) ~"d";
		queue[id]=0;
	}
	return queue;
	
}
/*
void order_queue_add(bool *queue, string order_to_add){ 	
	queue[order_to_add]=1;
}



int order_queue_find_dir(bool *queue,int current_floor,){
	
}

*/
