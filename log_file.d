import 	std.stdio,
		std.file,
		std.conv,
		std.string,
		elevio;

void init_log(int floors){
	int entries = 3*floors;
	string filename="log.lg";
	if(!exists(filename)){
		auto f = File(filename, "w");
		for(int i = 0; i < entries; i++){
			f.writeln("0");
		}
		f.close();
	}
}

int[] read_log(){
	string[] log_contents;
	log_contents = readText("log.lg").split;
	int[] int_log;
	int_log.length = log_contents.length;
	for(int i = 0; i<log_contents.length; i++){
		int_log[i] = to!int(log_contents[i]);
	}
	return int_log;
}

void write_log(int[] log_contents){
	auto f = File("log.lg", "w");
	foreach(i; log_contents){
		f.writeln(to!string(i));
	}
	f.close();
}

void log_put_entry(int floor_state, int floor, CallButton.Call call){
	auto log_contents = read_log;
	int m = to!int(log_contents.length / 3);
	int type;
	if (call == CallButton.Call.cab){type = 0; }
	else if (call == CallButton.Call.hallUp){type = 1; }
	else {type = 2; }
	log_contents[m*type + floor] = floor_state;
	write_log(log_contents);
}

void log_set_floor(int floor, CallButton.Call call){
	log_put_entry(1, floor, call);
}

void log_clear_floor(int floor, CallButton.Call call){
	log_put_entry(0, floor, call);
}
