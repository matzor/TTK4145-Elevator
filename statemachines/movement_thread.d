import std.stdio;
import state_interface;

//Thread-global variables
enum int STOP = 0 ;
enum int DOWN = 1;
enum int UP = 2;

//classes
class Stop_state : State{

	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//TODO: Make elevator stop
		//TODO: Open doors for 3 sek
	}
	override void s_do(){
		//TODO: Ask for orders from communiction thread
	}
	override int s_exit(){
		//TODO: Calculate movement direction
		//TODO: return movement driection
	}
}
class Down_state : State{
	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//TODO: Make elevator go down.
		//TODO: Tell floor sensor thread.
	}
	override void s_do(){
		//TODO: Listen from atfloor message from floor sensor thread
	}
	override int s_exit(){
		//TODO: If order here or end stop, return Stop state. Else reurn Down state. 
	}
}
class Up_state : State{
	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//TODO: Make elevator go up.
		//TODO: Tell floor sensor thread.
	}
	override void s_do(){
		//TODO: Listen from atfloor message from floor sensor thread
	}
	override int s_exit(){
		//TODO: If order here or end stop, return Stop state. Else reurn Up state. 
	}
}



//State machine loop
void movement_thread_run(){
	int movement_state =STOP;
	while(1){
		switch(movement_state){
			case STOP:
				Stop_state stop = new Stop_state;
				while(0){  //TODO: Check for exit condition
					stop.s_do();
				}
				movement_state=stop.s_exit();
				break;
			case DOWN:
				Down_state down = new Down_state;
				while(0){ //TODO: Check for exit condition
					down.s_do();
				}
				movement_state=down.s_exit();
				break;
			case UP:
				Up_state up = new Up_state;
				while(0){ //TODO: Check for exit condition
					up.s_do();
				}
				movement_state=up.s_exit();
				break;
			default:
				import std.string;
				throw new StringException("Invalid state");
				break;
		}
	}
}
