import std.stdio, std.conv, std.concurrency, core.thread;
import elevio, orders, network, bidding;

struct ElevatorControllerLog {
    string message;
    alias message this;
}

void door_open(int sec){
	doorLight(1);
	Thread.sleep((sec*1000).msecs);
	doorLight(0);
}

void run_movement (Tid loggerTid, int num_floors) {
    void log(string msg) {
        loggerTid.send(ElevatorControllerLog(msg));
    }

    int target_floor = -1;
    int current_floor = -1;
	Tid order_list_thread = receiveOnly!InitTid;
	int start_at_floor=1;
	receiveTimeout(3000.msecs,
	(FloorSensor f){
		start_at_floor=f;
	},
	);
	if(!start_at_floor){
		motorDirection(Dirn.up);
		order_list_thread.send(CallButton(1,CallButton.Call.cab));
	} else{
		order_list_thread.send(CallButton(0,CallButton.Call.cab));
		motorDirection(Dirn.down);
	}
	while(true){

        receive(
            (TargetFloor new_target){
				if(new_target>-1){
                	target_floor = new_target;
                	log("Got new order to floor "~to!string(target_floor));
					if (target_floor > current_floor) {
						if(current_floor!=-1){
	                    	motorDirection(Dirn.up);
						}
						order_list_thread.send(MotorDirUpdate(Dirn.up));
						current_floor=-1;
	                } else if (target_floor < current_floor) {
						if(current_floor!=-1){
    	                	motorDirection(Dirn.down);
						}
						order_list_thread.send(MotorDirUpdate(Dirn.down));
						current_floor=-1;
        	        }
					else{
						order_list_thread.send(FloorSensor(current_floor));
						writeln("Already on target floor");
					}
				}
				else{ writeln("finished all orders"); }
            },
            (FloorSensor floor_sensor){

                current_floor = floor_sensor;
                writeln("Floor sensor detected floor "~to!string(current_floor)~".");
                if (current_floor == target_floor
					|| current_floor == 0
					|| current_floor == num_floors-1
					){
                    motorDirection(Dirn.stop);
					door_open(1);
                    writeln("This is the target floor; stopping.");
					order_list_thread.send(FloorSensor(current_floor));
                }
            },
            (Obstruction a){
				writeln("CFloor: ",current_floor);
				order_list_thread.send(Obstruction(1));
                a.writeln;
            },
            (StopButton stop_btn){
                if (stop_btn) {
                    motorDirection(Dirn.stop);
                    log("Stop button pressed; stopping.");
                }
            },
        );
    }
}

void main(){
	int num_floors=4;
    initElevIO("localhost", 15657, num_floors);
	Tid movement_tid = spawn(&run_movement, thisTid,num_floors);
    spawn(&pollFloorSensor, movement_tid);
    spawn(&pollObstruction, movement_tid);
    spawn(&pollStopButton,  movement_tid);

	Tid order_list_tid = spawn(&run_order_list,num_floors,num_floors-1);
	order_list_tid.send(InitTid(movement_tid));

    /*TODO: Fix initial state of bidding thread*/
	auto bidding_thread = spawn(&bidding_main,0,Dirn.stop,order_list_tid);
	auto network_main_tid = spawn(&network.network_main, bidding_thread);

    spawn(&pollCallButtons, network_main_tid);

    while(true){
        receive(
            (ElevatorControllerLog msg){
                msg.writeln;
            }
        );
    }
}
