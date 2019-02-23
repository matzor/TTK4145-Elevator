import std.stdio, std.conv, std.concurrency;

import elevio;

struct ElevatorControllerLog {
    string message;
    alias message this;
}

void controlElevator (Tid loggerTid) {
    void log(string msg) {
        loggerTid.send(ElevatorControllerLog(msg));
    }

    int target_floor = -1;
    int current_floor = -1;

    while(true){
        receive(
            (CallButton call_btn){
                log("Call button pressed on floor "~to!string(call_btn.floor)~". Call type "~to!string(call_btn.call)~".");
                target_floor = call_btn.floor;
                if (target_floor > current_floor) {
                    motorDirection(Dirn.up);
                } else if (target_floor < current_floor) {
                    motorDirection(Dirn.down);
                }
            },
            (FloorSensor floor_sensor){
                current_floor = floor_sensor;
                log("Floor sensor detected floor "~to!string(current_floor)~".");
                if (current_floor == target_floor) {
                    motorDirection(Dirn.stop);
                    log("This is the target floor; stopping.");
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

    Tid elevatorController = spawn(&controlElevator, thisTid);


    spawn(&pollCallButtons, elevatorController);
    spawn(&pollFloorSensor, elevatorController);
    spawn(&pollObstruction, elevatorController);
    spawn(&pollStopButton,  elevatorController);

    while(true){
        receive(
            (ElevatorControllerLog msg){
                msg.writeln;
            }
        );
    }
}
