import  std.concurrency,
        std.datetime;

private __gshared ushort        peer_port;
private __gshared ubyte         _id;
private __gshared Duration      broadcast_interval;
private __gshared Duration      receive_timeout;

/*TODO: Move peer broadcast functions here!*/

void init_network_peers(ushort port, ubyte id, Duration interval, Duration timeout){
    peer_port = port; _id = id; broadcast_interval = 5*interval; receive_timeout = 5*timeout;
    //auto broadcastTxThread = spawn(&broadcast_tx);
    //auto broadcastRxThread = spawn(&broadcast_rx);
}
