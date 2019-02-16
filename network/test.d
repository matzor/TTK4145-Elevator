import  core.thread,
        std.concurrency,
        std.stdio,
        network;

int main(){
    auto network_main = spawn(&network.networkMain);

    Thread.sleep(500.msecs);

    Udp_msg test_msg;
    test_msg.dstId = network.id();
    test_msg.msgtype = 'e';
    test_msg.floor = 3;
    test_msg.bid = 100;
    test_msg.fines = 0;




    while(true){
        network.udp_send_safe(test_msg, thisTid);
        receiveTimeout(550.msecs,
            (bool ack) {writeln("Watchdog got ack: ", ack); }
            );
        Thread.sleep(500.msecs);
    }

    return 0;
}
