import std.stdio;
import std.string;
import state_interface;

//Thread-global variables
enum int AT_FLOOR = 1;
enum int BETWEEN_FLOORS = 0;

//classes
class At_floor : State{

	this(){
		this.s_entry();
	}
	ulong counter;//TODO: Remove this line
	override protected void s_entry(){
		writeln("ATFLOOR"); //TODO: Remove this line
		counter=10000000;//TODO: Remove this line
		//TODO: Send message to movement thread 
	}
	override void s_do(){
		counter--;//TODO: Remove this line
		//TODO: Check for message from movement thread
		
	}
	override int s_exit(){
		return BETWEEN_FLOORS;
	}
}
class Between_floors : State{
	ulong counter;//TODO: Remove this line
	this(){
		this.s_entry();
	}
	~this(){
		writeln("DEAD");
	}
	override protected void s_entry(){
		writeln("BETWEEN"); //TODO: Remove this line
		counter=10000000;//TODO: Remove this line

		//Do nothing
	}
	override void s_do(){
		counter--; //TODO: Remove this line
		//Do nothing
	}
	override int s_exit(){
		return AT_FLOOR;
	}
}

//State machine loop
void floor_sensor_thread_run(){
	int floor_sensor_state =AT_FLOOR;
	while(1){
		switch(floor_sensor_state){
			case AT_FLOOR:
				At_floor at_f = new At_floor;
				while(at_f.counter>0){  //TODO: Check for exit condition
					at_f.s_do();
				}
				floor_sensor_state=at_f.s_exit();
				break;
			case BETWEEN_FLOORS:
				Between_floors be_f = new Between_floors;
				while(be_f.counter>0){ //TODO: CHeck for exit condition
					be_f.s_do();
				}
				floor_sensor_state=be_f.s_exit();
				break;
			default:
				throw new StringException("Invalid state");
				break;
		}
	}
}
