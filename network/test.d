import  core.thread,
        std.concurrency,
        std.stdio,
        network;

int main(){
    auto network_main = spawn(&network.networkMain);

    Thread.sleep(500.msecs);

    Udp_msg test_msg;
    test_msg.dstId = 255;
    test_msg.msgtype = 'e';
    test_msg.floor = 3;
    test_msg.bid = 100;
    test_msg.fines = 0;




    while(true){
        udp_send(test_msg);
        Thread.sleep(500.msecs);
    }

    return 0;
}
