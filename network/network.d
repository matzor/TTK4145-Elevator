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
        core.thread;
        //std.typecons, std.traits, std.meta,

private __gshared ushort        broadcastport   = 19668;
private __gshared ushort        com_port        = 19667;
private __gshared size_t        bufSize         = 1024;
private __gshared int           recvFromSelf    = 0;
private __gshared int           interval_ms     = 100;
private __gshared Duration      interval;
private __gshared int           timeout_ms      = 550;
private __gshared Duration      timeout;
private __gshared string        id_str          = "default";
private __gshared ubyte         _id;
private __gshared Tid           txThread, rxThread, safeTxThread;

ubyte id(){
    return _id;
}

struct TxEnable {
    bool enable;
    alias enable this;
}

struct PeerList {
    immutable(ubyte)[] peers;
    alias peers this;
}


void network_init(){
    string[] configContents;
    try {
        configContents = readText("net.conf").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "net_bcast_port",           &broadcastport,
            "net_bcast_bufsize",        &bufSize,
            "net_bcast_recvFromSelf",   &recvFromSelf,
            "net_com_port",             &com_port,
            "net_peer_timeout",         &timeout_ms,
            "net_peer_interval",        &interval_ms,
            "net_peer_id",              &id_str
        );

        writeln("Network init complete, config file read successfully");

    } catch(Exception e){
        writeln("Unable to load net config:\n", e.msg);
    }

    timeout = timeout_ms.msecs;
    interval = interval_ms.msecs;

    //Default id is last segment of ip address
    if(id_str == "default"){
        try{
            //This method assumes internet-connection, fix this??
            _id = new TcpSocket(new InternetAddress("google.com", 80))
            .localAddress
            .toAddrString
            .splitter('.')
            .array[$-1]
            .to!ubyte;

            //addr.toHostNameString doesn't work for some reason on linux
            /*
            auto a = new InternetAddress(30005);
            auto hostName = a.toHostNameString;
            auto serverip = getAddress(hostName); //server hostname
            auto serverip[1]
                .splitter(':');
            */

        }
        catch(Exception e){
            writeln("Unable to resolve id:\n", e.msg);}
    } else {
        _id = id_str.to!ubyte;
    }
}


/*Continually broadcasts own id on designated (broadcast)port every
interval_ms timsetep */
void broadcast_tx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr                    = new InternetAddress("255.255.255.255", broadcastport);
    auto    sock                    = new UdpSocket();
    ubyte[1] buf                    = [id];

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    bool txEnable = true;
    writeln("Ready to broadcast on port ", broadcastport);
    writeln("Broadcasting id: ", buf);
    while(true){
        receiveTimeout(interval,
            (TxEnable t){
                txEnable = t;
            }
        );
        if(txEnable){
            sock.sendTo(buf, addr);
        }
    }
    }catch(Throwable t){ t.writeln; throw t; }
}

/*Continually listens on the designated (broadcast)port for other peers.
New peers are added to a list of currently acitve connections. If no message
from peer before timeout_ms, peer is removed from list of connections. */
void broadcast_rx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr                    = new InternetAddress(broadcastport);
    auto    sock                    = new UdpSocket();

    ubyte[1]            buf;
    SysTime[ubyte]      lastSeen;
    bool                listHasChanges;

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.Socket.setOption(SocketOptionLevel.SOCKET,
        SocketOption.RCVTIMEO, timeout);   //sets timeout on receive

    sock.bind(addr);
    writeln("Ready to listen on port ", broadcastport);

    while(true){
        listHasChanges  = false;
        buf[]           = 0;

        sock.receiveFrom(buf);

        if(buf[0] != 0){
            if(buf[0] !in lastSeen){
                listHasChanges = true;
            }
            lastSeen[buf[0]] = Clock.currTime;
        }

        foreach(k, v; lastSeen){
            if(Clock.currTime - v > timeout){
                listHasChanges = true;
                lastSeen.remove(k);
                writeln("Lost peer ", k);
            }
        }

        if(listHasChanges){
            writeln("Peerlist changed!");
            ownerTid.send(PeerList(lastSeen.keys.idup));
        }
    }
    } catch(Throwable t){ t.writeln; throw t; }
}

struct Udp_msg{
        ubyte     srcId     = 0;
        ubyte     dstId     = 0;
        char      msgtype   = 0;    //"i" || "e" || "a" (internal / external / ack)
        int       floor     = 0;    //floor of order
        int       bid       = 0;    //bid for order
        int       fines     = 0;    //"targetID"
        int       ack       = 0;    //1: message must be ACKed
        int       ack_id    = 0;
}

struct Udp_safe_msg{
    Udp_msg msg;
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
      msg.srcId     = to!ubyte(temp[0]);
      msg.dstId     = to!ubyte(temp[1]);
      msg.msgtype = to!char(temp[2]);
      msg.floor     = to!int(temp[3]);
      msg.bid       = to!int(temp[4]);
      msg.fines     = to!int(temp[5]);
      msg.ack       = to!int(temp[6]);
      msg.ack_id    = to!int(temp[7]);
      return msg;
}

void UDP_tx(){
    /*Simple transmit should work. Sends a Udp_msg type, converted to string
    over UDP.
    Use: txTid.send(msg)
    Does not wait for ack. Sends message only once.
    TODO: make transmit wait for ack or no? Own function for this. */

    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr    = new InternetAddress("255.255.255.255", com_port);
    auto    sock    = new UdpSocket();

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

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


void UDP_rx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto              addr    = new InternetAddress(com_port);
    auto              sock    = new UdpSocket();
    char[1024]        buf        = "";

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    sock.bind(addr);

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

void udp_safe_send_handler(){
    scope(exit) writeln(__FUNCTION__, " died");
    try{
    Tid[int] active_senders;
    while(true){
        receive(
            (Udp_msg msg){
                switch(msg.msgtype){
                    case 'a':
                        if (msg.ack_id in active_senders){
                            active_senders[msg.ack_id].send(msg);
                        }
                        break;
                    default:
                        if (msg.ack_id !in active_senders){
                            active_senders[msg.ack_id] = spawn(&udp_safe_sender, msg);
                        }
                        break;
                }
            },
            (int acked_ack_id) {
                active_senders.remove(acked_ack_id);
            }
            );
    }
    } catch(Throwable t){ t.writeln;  throw t; }
}

void udp_safe_sender(Udp_msg msg){
    scope(exit) writeln(__FUNCTION__, " died");
    try{
            bool ack = false;
            bool txEnable = true;
            while (!ack){
                if (txEnable){
                    udp_send(msg);
                }
                receiveTimeout(interval,
                    (Udp_msg answer_msg){
                        if((msg.ack_id == answer_msg.ack_id) && (msg.srcId == answer_msg.dstId))
                        {
                            ack = true;
                        }
                    },
                    (TxEnable t) {txEnable = t;}
                    );
            }
            ownerTid.send(msg.ack_id);
        }catch(Throwable t){ t.writeln;  throw t; }
}


void udp_send(Udp_msg msg){
    txThread.send(msg);
}


void udp_send_safe(Udp_msg msg){
    msg.ack = 1;
    if (!msg.ack_id){
        /*TODO: Create random/unique ack_id*/
    }
    safeTxThread.send(msg);
}

void udp_ack_confirm(Udp_msg received_msg){
    Udp_msg msg;
    msg.srcId = _id;
    msg.dstId = received_msg.srcId;
    msg.msgtype = 'a';
    msg.floor = 0;
    msg.bid = 0;
    msg.fines = 0;
    msg.ack = 0;
    msg.ack_id = received_msg.ack_id;
    udp_send(msg);
}

void networkMain(){
    network_init();
    auto broadcastTxThread = spawn(&broadcast_tx);
    auto broadcastRxThread = spawn(&broadcast_rx);

    txThread        = spawn(&UDP_tx);
    rxThread        = spawn(&UDP_rx);
    safeTxThread   = spawn(&udp_safe_send_handler);


    Thread.sleep(250.msecs); //wait for all threads to start...


    while(true){
        receive(
            (PeerList p){
                /*TODO: Handle PeerList updates*/
                writeln("Received peerlist: ", p);
            },
            (Udp_msg msg){
                /*TODO: Handle UDP message*/

                switch(msg.msgtype)
                {
                    case 'e':
                        /*TODO: Handle external orders*/
                        writeln("Received message type ", 'e');
                        /*udp_ack_confirm probably shouldnt be called here like this
                        For testing purposes only.  */
                        if((msg.ack) && msg.dstId == _id){
                            udp_ack_confirm(msg);
                        }
                        break;
                    case 'i':
                        /*TODO: Handle internal orders*/
                        writeln("Received message type ", 'i');
                        break;
                    case 'a':
                        /*TODO: Handle ack messages*/
                        writeln("Received message type ", 'a');
                        safeTxThread.send(msg);
                        break;
                    default:
                        /*TODO: Handle invalid message type*/
                        writeln("Invalid message type");
                        break;
                }
        }
        );

    }
}
