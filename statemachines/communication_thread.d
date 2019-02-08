import std.stdio;
import std.string;
import state_interface;

//Thread-global variables
enum int LISTEN = 0 ;
enum int BID = 1;
enum int HANDLE_QUEUE = 2;

//classes
class Listen_queue_state : State{
	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//Do nothing
	}
	override void s_do(){
		//TODO: Listen for internal orders
		//TODO: Listen for external orders
	}
	override int s_exit(){
		//Do nothing
	}
}
class Bid_state : State{

	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//TODO: Calculate bid
		//TODO: Send bid
	}
	override void s_do(){
		//TODO: Wait for bids until timeout
	}
	override int s_exit(){
		//TODO: Do watchdog
	}
}
class Handle_queue_state : State{
	this(){
		this.s_entry();
	}
	override protected void s_entry(){
		//TODO: Update queue
		//TODO: Send queue to network
	}
	override void s_do(){
		//Do nothing
	}
	override int s_exit(){
		//Do nothing		
	}
}




//State machine loop
void Communication_thread_run(){
	int communication_state =LISTEN;
	while(1){
		switch(connmunication_state){
			case LISTEN:
				Listen_state listen = new Listen_state;
				while(0){  //TODO: Check for exit condition
					listen.s_do();
				}
				communication_state=listen.s_exit();
				break;
			case BID:
				Bid_state bid = new Bid_state;
				while(0){ //TODO: CHeck for exit condition
					bid.s_do();
				}
				communication_state=bid.s_exit();
				break;
			case HANDLE_QUEUE:
				Handle_queue_state handl_q = new Handle_queue_state;
				while(0){ //TODO: CHeck for exit condition
					handl_q.s_do();
				}
				communication_state=handl_q.s_exit();
				break;
			default:
				throw new StringException("Invalid state");
				break;
		}
	}
}
