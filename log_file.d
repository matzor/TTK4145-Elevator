import 	std.stdio,
		std.file,
		std.conv,
		std.string;
		
import	elevio;

private __gshared int           number_of_floors;

void init_log(int floors){
	number_of_floors = floors;
	int entries = 3*number_of_floors;
	string filename="log.lg";
	int[] new_log_content;
	new_log_content.length = number_of_floors*3;
	if(!exists(filename)){
		write_log(new_log_content);
	}
	else{
		auto log_contents = read_log();
		if (log_contents.length < number_of_floors*3){
			fix_log();
		}
	}
}

int[] read_log(){
	try{
		string[] log_contents;
		log_contents = readText("log.lg").split;
		int[] int_log;
		int_log.length = log_contents.length;
		for(int i = 0; i<log_contents.length; i++){
			int_log[i] = to!int(log_contents[i]);
		}
		return int_log;
	}
	catch(Exception e){
		writeln("LOG ERROR: ", e);
		auto new_log_content = fix_log();
		return new_log_content;
	}
}

void log_set_floor(int floor, CallButton.Call call){
	log_put_entry(1, floor, call);
}

void log_clear_floor(int floor, CallButton.Call call){
	log_put_entry(0, floor, call);
}


/* --- Private --- */

/*	If for some reason log is corrupted (should in theory never happen),
 	add a cab call to all floors to be safe that all floors will be served */
int[] fix_log(){
	int[] new_log_content;
	new_log_content.length = number_of_floors*3;
	new_log_content[0 .. 4] = 1;
	write_log(new_log_content);
	return new_log_content;
}

void write_log(int[] log_contents){
	auto f = File("log.lg", "w");
	foreach(i; log_contents){
		f.writeln(to!string(i));
	}
	f.close();
}

void log_put_entry(int floor_state, int floor, CallButton.Call call){
	auto log_contents = read_log();
	int m = to!int(log_contents.length / 3);
	int type;
	if (call == CallButton.Call.cab){type = 0; }
	else if (call == CallButton.Call.hallUp){type = 1; }
	else {type = 2; }
	log_contents[m*type + floor] = floor_state;
	write_log(log_contents);
}
