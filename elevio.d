import  std.concurrency,
        std.conv,
        std.datetime,
        std.string,
        std.socket,
        std.stdio,
        core.sync.mutex,
        core.thread;

enum HallCall : int {
    up,
    down
}

enum Dirn : int {
    down    = -1,
    stop    = 0,
    up      = 1
}


struct CallButton {
	enum Call : int {
		hallUp,
		hallDown,
		cab,
	}
    int floor;
    Call call;
}
struct FloorSensor {
    int floor;
    alias floor this;
}
struct StopButton {
    bool stop;
    alias stop this;
}
struct Obstruction {
    bool obstruction;
    alias obstruction this;
}


private __gshared TcpSocket sock;
private __gshared Duration  pollRate    = 20.msecs;
private __gshared int       numFloors   = 4;
private __gshared Mutex     mtx;

void initElevIO(string ip, ushort port, int numFloors){
    try {
        sock = new TcpSocket();
        sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
        sock.connect(new InternetAddress(ip, port));
    } catch(Exception e){
        writeln(__FUNCTION__, ": Unable to connect to elevator");
        throw e;
    }


    // Reset lights
    for(auto c = CallButton.Call.min; c <= CallButton.Call.max; c++){
        foreach(f; 0..numFloors){
            callButtonLight(f, c, false);
        }
    }
    floorIndicator(0);
    stopButtonLight(false);
    doorLight(false);


    .numFloors = numFloors;

}

shared static this(){
    mtx = new Mutex;
}

shared static ~this(){
    motorDirection(Dirn.stop);
}

void pollCallButtons(Tid receiver){
    bool[][] call = new bool[][](numFloors, CallButton.Call.max+1);
    while(true){
        Thread.sleep(pollRate);
        for(auto c = CallButton.Call.min; c <= CallButton.Call.max; c++){
            foreach(f; 0..numFloors){
                if(call[f][c] != (call[f][c] = callButton(f, c))  &&  call[f][c]){

                    receiver.send(CallButton(f, c));
                }
            }
        }
    }
}

void pollFloorSensor(Tid receiver){
    int floor = -1;
    while(true){
        Thread.sleep(pollRate);
        if(floor != (floor = floorSensor())  &&  floor != -1){
            receiver.send(FloorSensor(floor));
        }
    }
}

void pollStopButton(Tid receiver){
    bool stop = 0;
    while(true){
        Thread.sleep(pollRate);
        if(stop != (stop = stopButton())){
            receiver.send(StopButton(stop));
        }
    }
}

void pollObstruction(Tid receiver){
    bool obstr = 0;
    while(true){
        Thread.sleep(pollRate);
        if(obstr != (obstr = obstruction())){
            receiver.send(Obstruction(obstr));
        }
    }
}




void motorDirection(Dirn d){
    ubyte[4] buf = [1, cast(ubyte)d, 0, 0];
    synchronized(mtx){
        sock.send(buf);
    }
}

void callButtonLight(int floor, CallButton.Call call, bool on){
    ubyte[4] buf = [2, cast(ubyte)call, cast(ubyte)floor, cast(ubyte)on];
    synchronized(mtx){
        sock.send(buf);
    }
}

void floorIndicator(int floor){
    ubyte[4] buf = [3, cast(ubyte)floor, 0, 0];
    synchronized(mtx){
        sock.send(buf);
    }
}

void doorLight(bool on){
    ubyte[4] buf = [4, cast(ubyte)on, 0, 0];
    synchronized(mtx){
        sock.send(buf);
    }
}

void stopButtonLight(bool on){
    ubyte[4] buf = [5, cast(ubyte)on, 0, 0];
    synchronized(mtx){
        sock.send(buf);
    }
}




bool callButton(int floor, CallButton.Call call){
    ubyte[4] buf = [6, cast(ubyte)call, cast(ubyte)floor, 0];
    synchronized(mtx){
        sock.send(buf);
        sock.receive(buf);
    }
    return buf[1].to!bool;
}

int floorSensor(){
    ubyte[4] buf = [7, 0, 0, 0];
    synchronized(mtx){
        sock.send(buf);
        sock.receive(buf);
    }
    return buf[1] ? buf[2] : -1;
}

bool stopButton(){
    ubyte[4] buf = [8, 0, 0, 0];
    synchronized(mtx){
        sock.send(buf);
        sock.receive(buf);
    }
    return buf[1].to!bool;
}

bool obstruction(){
    ubyte[4] buf = [9, 0, 0, 0];
    synchronized(mtx){
        sock.send(buf);
        sock.receive(buf);
    }
    return buf[1].to!bool;
}
