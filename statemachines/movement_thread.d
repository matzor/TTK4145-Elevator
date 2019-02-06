import std.stdio;
import std.string;
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
	}
	override void s_do(){
		//TODO: Listen from atfloor message from floor sensor thread
	}
	override int s_exit(){
		//TODO: If order here, return Stop state. Else reurn Down state. 
	}
}
class Up_state : State{
	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//TODO: Make elevator go up.
	}
	override void s_do(){
		//TODO: Listen from atfloor message from floor sensor thread
	}
	override int s_exit(){
		//TODO: If order here, return Stop state. Else reurn Up state. 
	}
}



//State machine loop
void movement_run(){
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
				while(0){ //TODO: CHeck for exit condition
					down.s_do();
				}
				movement_state=down.s_exit();
				break;
			case UP:
				Up_state up = new Up_state;
				while(0){ //TODO: CHeck for exit condition
					up.s_do();
				}
				movement_state=up.s_exit();
				break;
			default:
				throw new StringException("Invalid state");
				break;
		}
	}
}
