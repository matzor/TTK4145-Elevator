import std.stdio, std.conv, std.concurrency;

import elevio, orders;

struct ElevatorControllerLog {
    string message;
    alias message this;
}

NewOrderRequest button_to_order (CallButton btn) {
	NewOrderRequest n;
	n.floor = btn.floor;
	n.call=btn.call;
	//TODO: remove this maybe? n=btn
	return n;
}

void run_movement (Tid loggerTid, Tid order_list_thread) {
    void log(string msg) {
        loggerTid.send(ElevatorControllerLog(msg));
    }

    int target_floor = -1;
    int current_floor = -1;

    while(true){
        receive(	
            (TargetFloor new_target){
                target_floor = new_target;
                log("Got new order to floor "~to!string(target_floor));
                if (target_floor > current_floor) {
                    motorDirection(Dirn.up);
                } else if (target_floor < current_floor) {
                    motorDirection(Dirn.down);
                }
            },
            (FloorSensor floor_sensor){
                current_floor = floor_sensor;
                writeln("Floor sensor detected floor "~to!string(current_floor)~".");
                if (current_floor == target_floor) {
                    motorDirection(Dirn.stop);
                    writeln("This is the target floor; stopping.");
					order_list_thread.send(FloorSensor(current_floor));
                }
            },
            (Obstruction a){
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

    initElevIO("localhost", 15657, 4);
	Tid movement_tid;
	Tid order_list_tid;

    movement_tid = spawn(&run_movement, thisTid, order_list_tid); 
	order_list_tid = spawn(&run_order_list,4,1,movement_tid);


    spawn(&pollCallButtons, order_list_tid);
    spawn(&pollFloorSensor, movement_tid);
    spawn(&pollObstruction, movement_tid);
    spawn(&pollStopButton,  movement_tid);

    while(true){
        receive(
            (ElevatorControllerLog msg){
                msg.writeln;
            }
        );
    }
}
