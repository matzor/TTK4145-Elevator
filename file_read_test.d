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

int[] read_log(int floors){
	string[] log_contents;
	log_contents = readText("log.lg").split;
	int[] int_log;
	for(int i = 0; i<log_contents.length; i++){
		writeln(i);
		int_log[i] = to!int(log_contents[i]);
	}
	return int_log;
}

void write_log(string[] log_contents){
	auto f = File("log.lg", "w");
	foreach(i; log_contents){
		f.writeln(i);
	}
	f.close();
}

void main(){
	//init_log(4);
	int floors = 4;
	auto log_contents = read_log(floors);
	writeln(log_contents);
	//log_contents[3] = "1";
	//write_log(log_contents);
}
