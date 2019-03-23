import 	std.stdio,
		std.file,
		std.conv,
		std.string;

void init_log(int floors){
	auto f = File("log.lg", "w");
	for(int i = 0; i < floors; i++){
		f.writeln("0");
	}
	f.close();
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

void log_set_floor(int floor){
	auto log_contents = read_log;
	log_contents[floor] = 1;
	write_log(log_contents);
}

void log_clear_floor(int floor){
	auto log_contents = read_log;
	log_contents[floor] = 0;
	write_log(log_contents);
}

void main(){
	int floors = 4;
	//init_log(floors);
	try{
		auto log_contents = read_log();
		writeln(log_contents);
	}
	catch (Exception e) {
			writeln("Error openeing log file!\n", "Initializing new empty log...");
			init_log(floors);
	}

	writeln("Log tests here:");
	writeln(read_log());
	log_set_floor(0);
	log_set_floor(1);
	writeln(read_log());
	log_clear_floor(1);
	writeln(read_log());
}
