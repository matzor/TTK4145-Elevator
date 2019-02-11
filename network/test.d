import  core.thread,
        std.concurrency,
        network;

int main(){
    auto network_main = spawn(&network.networkMain);

    Thread.sleep(500.msecs);

    Udp_msg test_msg;
    test_msg.srcId = network.id();
    test_msg.dstId = network.id();
    test_msg.msgtype = 'e';
    test_msg.floor = 3;
    test_msg.bid = 100;
    test_msg.fines = 0;
    test_msg.ack = 1;
    test_msg.ack_id = 5;



    while(true){
        network.udp_send_safe(test_msg);
        Thread.sleep(500.msecs);
    }

    return 0;
}
