import std.stdio;
import floor_sensor_thread;
import std.concurrency;
import order_queue;

void main(){
	foreach(i; 0 ..3){
		auto oq=order_queue_init(4);
		writeln(oq);
	}
}
