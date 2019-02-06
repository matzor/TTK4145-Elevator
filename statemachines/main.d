import floor_sensor_thread;
import std.concurrency;

void main(){
	spawn(&floor_sensor_thread_run);
	while(1){}
}
