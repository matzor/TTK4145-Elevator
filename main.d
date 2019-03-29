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
bool door_open = false;

enum ThreadName {
	logger,
	movement,
	network,
	bidding,
	order_list,
}

struct ElevatorControllerLog {
	string message;
	alias message this;
}

struct DoorClosedMessage {}

void config_init() {
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
	} catch(Exception e) {
		writeln("Unable to load elevator config:\n", e.msg);
		writeln("Using failsafe default config");
	}
	door_wait = door_wait_ms.msecs;
	watchdog_timer = watchdog_timer_ms.msecs;
}

void run_door_cycle() {
	doorLight(1);
	Thread.sleep(door_wait);
	doorLight(0);
	ownerTid.send(DoorClosedMessage());
}

void open_door() {
	if (!door_open) {
		door_open = true;
		spawn(&run_door_cycle);
	}
}

void run_movement (int num_floors) {
	// Wait for thread list
	Tid[ThreadName] threads;
	receive((shared(Tid[ThreadName]) t) {threads = cast(Tid[ThreadName])t;});
	writeln("List received! " ~ to!string(threads));
	Tid order_list_thread = threads[ThreadName.order_list];
	Tid bidding_thread = threads[ThreadName.bidding];

	writeln("Elevator initializing");
	void log(string msg) {
		threads[ThreadName.logger].send(ElevatorControllerLog(msg));
	}

	spawn(&pollFloorSensor, thisTid);
	spawn(&pollObstruction, thisTid);
	spawn(&pollStopButton,  thisTid);
	spawn(&pollCallButtons, threads[ThreadName.network]);

	int target_floor = -1;
	int current_floor = -1;
	Dirn current_dir = Dirn.stop;
	void safe_activate_motor () {
		if (!door_open) motorDirection(current_dir);
		else motorDirection(Dirn.stop);
	}

	int start_at_floor = 1;
	receiveTimeout(3000.msecs,
		(FloorSensor f) {
			start_at_floor = f;
		},
	);
	if(!start_at_floor) {
		current_dir = Dirn.up;
	} else {
		current_dir = Dirn.down;
	}
	safe_activate_motor();

	while(true) {
		receive(
			(TargetFloor new_target) {
				if(new_target > -1) {
					target_floor = new_target;
					log("Got new order to floor " ~ to!string(target_floor));
					if (target_floor > current_floor) {
						current_dir = Dirn.up;
						safe_activate_motor();
						order_list_thread.send(MotorDirUpdate(Dirn.up));
					} else if (target_floor < current_floor) {
						current_dir = Dirn.down;
						safe_activate_motor();
						order_list_thread.send(MotorDirUpdate(Dirn.down));
					} else if (current_dir == Dirn.stop) {
						open_door();
						order_list_thread.send(TargetFloorReached(current_floor));
						writeln("Already on target floor");
					}
				} else {
					writeln("finished all orders");
				}
				//Updating states of bidding thread
				State_vector states;
				states.dir = current_dir;
				states.floor = current_floor;
				bidding_thread.send(states);
			},
			(FloorSensor floor_sensor) {
				current_floor = floor_sensor;
                floorIndicator(current_floor);
				order_list_thread.send(FloorSensor(current_floor));
				writeln("Floor sensor detected floor " ~ to!string(current_floor) ~ ".");
				if (
					current_floor == target_floor
					|| current_floor == 0
					|| current_floor == num_floors - 1
				){
					current_dir = Dirn.stop;
					safe_activate_motor();
					order_list_thread.send(TargetFloorReached(current_floor));
					open_door();
					writeln("This is the target floor; stopping.");
				}
			},
			(DoorClosedMessage m) {
				door_open = false;
				safe_activate_motor();
			},
			(Obstruction a) {
				writeln("CFloor: ", current_floor);
				order_list_thread.send(Obstruction(1));
				a.writeln;
			},
			(StopButton stop_btn) {
				if (stop_btn) {
					current_dir = Dirn.stop;
					safe_activate_motor();
					log("Stop button pressed; stopping.");
				}
			},
		);
	}
}

void main(){
	config_init();
	initElevIO("localhost", 15657, num_floors);

	writeln("Here!");
	// Spawning threads
	Tid[ThreadName] threads;
	threads[ThreadName.logger] = thisTid;
	threads[ThreadName.movement] = spawn(&run_movement, num_floors);
	threads[ThreadName.order_list] = spawn(&run_order_list, num_floors, num_floors-1);
	threads[ThreadName.bidding] = spawn(&bidding_main, 0, Dirn.stop, threads[ThreadName.order_list]);
	threads[ThreadName.network] = spawn(&network_main);
	writeln("But also here, eh?");

	// Sending threads needed Tids
	foreach(Tid t; threads) {
		shared(Tid[ThreadName]) thr = cast(shared Tid[ThreadName])threads.dup;
		t.send(thr);
	}

	writeln("We even sent some stuff!");

	while(true) {
		receive(
			(ElevatorControllerLog msg) {
				msg.writeln;
			}
	   );
	}
}
