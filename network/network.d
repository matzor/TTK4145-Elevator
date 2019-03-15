import  std.array,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.file,
        std.getopt,
        std.socket,
        std.stdio,
        std.string,
        std.datetime,
        core.thread,
        network_peers;

private __gshared ushort        broadcastport       = 19668;
private __gshared ushort        com_port            = 19667;
private __gshared int           recvFromSelf        = 0;
private __gshared int           interval_ms         = 100;
private __gshared Duration      interval;
private __gshared int           timeout_ms          = 550;
private __gshared Duration      timeout;
private __gshared string        id_str              = "default";
private __gshared ubyte         _id;
private __gshared int           retransmit_count    = 5;
private __gshared Tid           txThread, rxThread;

ubyte id(){
    return _id;
}

void network_init(){
    string[] configContents;
    try {
        configContents = readText("net.conf").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "net_bcast_port",           &broadcastport,
            "net_bcast_recvFromSelf",   &recvFromSelf,
            "net_com_port",             &com_port,
            "net_peer_timeout",         &timeout_ms,
            "net_peer_interval",        &interval_ms,
            "net_peer_id",              &id_str,
            "net_retransmit_count",     &retransmit_count,
        );

        writeln("Network init complete, config file read successfully");

    } catch(Exception e){
        writeln("Unable to load net config:\n", e.msg);
    }

    timeout = timeout_ms.msecs;
    interval = interval_ms.msecs;

    if(id_str == "default"){
        try{
                _id = 0;
        }
        catch(Exception e){
            writeln("Unable to resolve id:\n", e.msg);}
    } else {
        _id = id_str.to!ubyte;
    }
}

struct Udp_msg{
        ubyte     srcId     = 0;
        ubyte     dstId     = 255;  //255: broadcast
        char      msgtype   = 0;    //'i' || 'e' || 'c' || 'a'  (internal / external / confirmed / ack)
        int       floor     = 0;    //floor of order
        int       bid       = 0;    //bid for order
        ubyte     fines     = 0;    //"targetID"
        bool      ack       = 0;    //true: message must be ACKed
        int       ack_id    = 0;    //unique id for each message sent
}


string udp_msg_to_string(Udp_msg msg){
    string str = to!string(msg.srcId)
        ~ "," ~ to!string(msg.dstId)
        ~ "," ~ to!string(msg.msgtype)
        ~ "," ~ to!string(msg.floor)
        ~ "," ~ to!string(msg.bid)
        ~ "," ~ to!string(msg.fines)
        ~ "," ~ to!string(msg.ack)
        ~ "," ~ to!string(msg.ack_id);
    return str;
}

Udp_msg string_to_udp_msg(string str){
      Udp_msg msg;
      auto temp     = str.splitter(',').array;
      if (temp.length >= 7){
          msg.srcId     = to!ubyte(temp[0]);
          msg.dstId     = to!ubyte(temp[1]);
          msg.msgtype   = to!char(temp[2]);
          msg.floor     = to!int(temp[3]);
          msg.bid       = to!int(temp[4]);
          msg.fines     = to!ubyte(temp[5]);
          msg.ack       = to!bool(temp[6]);
          msg.ack_id    = to!int(temp[7]);
      }
      else{writeln("Corrupt message format");}
      return msg;
}

void udp_tx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr    = new InternetAddress("255.255.255.255", com_port);
    auto    sock    = new UdpSocket();

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    writeln(__FUNCTION__, " started");

    while(true){
        receive(
            (Udp_msg msg){
                auto str_msg = udp_msg_to_string(msg);
                sock.sendTo(str_msg, addr);
            }
            );
    }
    }catch(Throwable t){ t.writeln; throw t; }
}


void udp_rx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto              addr    = new InternetAddress(com_port);
    auto              sock    = new UdpSocket();
    char[1024]        buf        = "";

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.bind(addr);
    writeln(__FUNCTION__, " started");

    while(true){
        auto buf_length = sock.receive(buf);
        if (buf_length>0) {
            auto received_msg = to!string(buf[0 .. buf_length]);
            auto msg = string_to_udp_msg(received_msg);
            ownerTid.send(msg);
        }
    }

    } catch(Throwable t){ t.writeln;  throw t; }
}

void udp_send(Udp_msg msg){
        msg.srcId = _id;
        txThread.send(msg);
}


void networkMain(){
    network_init();
    auto network_peers_thread = spawn(&network_peers.init_network_peers, broadcastport, _id, interval, timeout);
    txThread                  = spawn(&udp_tx);
    rxThread                  = spawn(&udp_rx);


    Thread.sleep(500.msecs); //wait for all threads to start... do we need this?

    while(true){
        receive(
            (PeerList p){
                /*TODO: Handle PeerList updates
                peerlist should be sent to safe_send_handler */
                writeln("Received peerlist: ", p);
            },
            (Udp_msg msg){
                /*TODO: Handle UDP message*/
                if (msg.dstId == _id || msg.dstId == 255){
                    switch(msg.msgtype)
                    {
                        case 'e':
                            /*TODO: Handle external orders*/
                            writeln("Received message type EXTERNAL from id ", msg.srcId);
                            break;
                        case 'i':
                            /*TODO: Handle internal orders*/
                            writeln("Received message type INTERNAL from id ", msg.srcId);
                            break;
                        case 'c':
                            /*TODO: Handle confirmed orders*/
                            writeln("Received message type CONFIRMED from id ", msg.srcId);
                            break;
                        case 'a':
                            /*Ack messages used internally for udp transmission only*/
                            writeln("Received message type ACK from id ", msg.srcId);
                            break;
                        default:
                            /*TODO: Handle invalid message type*/
                            writeln("Invalid message type");
                            break;
                    }
            }
        }
        );
    }
}
