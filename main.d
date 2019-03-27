import  std.stdio,
        std.conv,
        std.concurrency,
        core.thread;
import  elevio,
        orders,
        network,
        bidding;

private __gshared   int           num_floors            = 4;
private __gshared   int           door_wait_ms          = 1000;
private __gshared   Duration      door_wait;
private __gshared   int           watchdog_timer_ms     = 30000;
private __gshared   Duration      watchdog_timer;

struct ElevatorControllerLog {
    string message;
    alias message this;
}

void config_init(){
    import std.getopt, std.file, std.string, std.conv;
    string[] configContents;
    try {
        configContents = readText("elev.conf").split;
        getopt(configContents,
            std.getopt.config.passThrough,
            "elev_num_floors",          &num_floors,
            "elev_door_wait",           &door_wait_ms,
            "elev_watchdog_timer",      &watchdog_timer_ms,
        );

        writeln("Elevator config file read successfully");

    } catch(Exception e){
        writeln("Unable to load elevator config:\n", e.msg);
        writeln("Using failsafe default config");
    }
    door_wait = door_wait_ms.msecs;
    watchdog_timer = watchdog_timer_ms.msecs;
}

void door_open(){
	doorLight(1);
	Thread.sleep(door_wait);
	doorLight(0);
}

void run_movement (Tid loggerTid, int num_floors) {
    writeln("Elevator initializing");
    void log(string msg) {
        loggerTid.send(ElevatorControllerLog(msg));
    }

    int target_floor = -1;
    int current_floor = -1;
	Dirn current_dir = Dirn.stop;
	Tid order_list_thread = receiveOnly!InitTid;
	int start_at_floor=1;
	receiveTimeout(3000.msecs,
	(FloorSensor f){
		start_at_floor=f;
	},
	);
	if(!start_at_floor){
		motorDirection(Dirn.up);
	} else{
		motorDirection(Dirn.down);
	}
	while(true){

        receive(
            (TargetFloor new_target){
				if(new_target>-1){
                	target_floor = new_target;
                	log("Got new order to floor "~to!string(target_floor));
					if (target_floor > current_floor) {
	              	    motorDirection(Dirn.up);
						current_dir=Dirn.up;
						order_list_thread.send(MotorDirUpdate(Dirn.up));	
	                } else if (target_floor < current_floor) {
    	                motorDirection(Dirn.down);
						current_dir=Dirn.down;
						order_list_thread.send(MotorDirUpdate(Dirn.down));
						
        	        }
					else if(current_dir==Dirn.stop){
						door_open();
						order_list_thread.send(AlreadyOnFloor(current_floor));
						writeln("Already on target floor");
					}
				}
				else{ writeln("finished all orders"); }
            },
            (FloorSensor floor_sensor){
                current_floor = floor_sensor;
                writeln("Floor sensor detected floor "~to!string(current_floor)~".");
                if (
					current_floor == target_floor
					|| current_floor == 0
					|| current_floor == num_floors-1
				){
                    motorDirection(Dirn.stop);
					current_dir=Dirn.stop;
					door_open();
                    writeln("This is the target floor; stopping.");
					order_list_thread.send(FloorSensor(current_floor));
                }
				//current_floor=-1;
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
	config_init();
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
