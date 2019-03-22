import std.stdio, std.container;
import std.algorithm;
import std.array,std.range;
import std.concurrency;
import core.thread;
import std.stdio;

import 	bidding,
		elevio,
		network;

void main(){

	Dirn dir = Dirn.stop;
	auto bidding_thread = spawn(&bidding_main, -1, dir);
	auto network_main = spawn(&network.networkMain, bidding_thread);

    Thread.sleep(500.msecs);

    Udp_msg test_msg;
    test_msg.dstId = 255;
    test_msg.msgtype = 'e';
    test_msg.floor = 2;
    test_msg.bid = 0;
    test_msg.fines = 0;
	test_msg.new_order = 1;
	test_msg.dir = 1;

	while(true){
		udp_send(test_msg);
        Thread.sleep(500.msecs);
	}
}
