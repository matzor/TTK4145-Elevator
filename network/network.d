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
private __gshared size_t        bufSize             = 1024; //is this even used?
private __gshared int           recvFromSelf        = 0;
private __gshared int           interval_ms         = 100;
private __gshared Duration      interval;
private __gshared int           timeout_ms          = 550;
private __gshared Duration      timeout;
private __gshared string        id_str              = "default";
private __gshared ubyte         _id;
private __gshared int           retransmit_count    = 5;
private __gshared Tid           txThread, rxThread, safeTxThread;

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
            "net_bcast_bufsize",        &bufSize,
            "net_bcast_recvFromSelf",   &recvFromSelf,
            "net_com_port",             &com_port,
            "net_peer_timeout",         &timeout_ms,
            "net_peer_interval",        &interval_ms,
            "net_peer_id",              &id_str,
            "net_retransmit_count",     &retransmit_count
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
        char      msgtype   = 0;    //"i" || "e" || "a" (internal / external / ack)
        int       floor     = 0;    //floor of order
        int       bid       = 0;    //bid for order
        ubyte     fines     = 0;    //"targetID"
        bool      ack       = 0;    //1: message must be ACKed
        int       ack_id    = 0;
}

struct Udp_msg_owner{
    Udp_msg msg;
    Tid owner_thread;
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

void Udp_tx(){
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


void Udp_rx(){
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
    PeerList peers;
    bool sending_started;
    while(true){
        receive(
            (Udp_msg msg){              //Receiving acks
                if (msg.ack_id in active_senders){
                    active_senders[msg.ack_id].send(msg);
                }
            },
            (Udp_msg_owner owner_msg){  //Sending messages
                sending_started = false;
                Udp_msg msg = owner_msg.msg;
                Tid msg_owner_thread = owner_msg.owner_thread;
                if (msg.ack_id !in active_senders){                     //check if thread already exist, do nothing if exist
                    foreach(id;peers){
                        if (msg.dstId == id || msg.dstId == 255){       //check if dstId is alive/connected, or broadcast msg
                            active_senders[msg.ack_id] = spawn(&udp_safe_sender, msg, msg_owner_thread);
                            sending_started = true;
                            break;
                        }
                    }
                    if(!sending_started){msg_owner_thread.send(false); } //automatic nack if reciever not alive
                }
            },
            (int acked_ack_id) {
                active_senders.remove(acked_ack_id);
            },
            (PeerList p) {peers = p;}
            );
    }
    } catch(Throwable t){ t.writeln;  throw t; }
}

void udp_safe_sender(Udp_msg msg, Tid msg_owner_thread){
    //scope(exit) writeln(__FUNCTION__, " died");
    try{
            bool ack = false;
            for (int i = 0; i < retransmit_count; i++){
                udp_send(msg);
                receiveTimeout(interval,
                    (Udp_msg answer_msg){
                        if((msg.ack_id == answer_msg.ack_id) && ((answer_msg.dstId == msg.srcId)||(answer_msg.dstId == 255)))
                        {
                            ack = true;
                        }
                    }
                    );
                    if (ack){
                            break;
                    }
            }
            ownerTid.send(msg.ack_id);
            msg_owner_thread.send(ack);
        }catch(Throwable t){ t.writeln;  throw t; }
}


void udp_send(Udp_msg msg){
        msg.srcId = _id;
        txThread.send(msg);
}

void udp_send_safe(Udp_msg msg, Tid msg_owner_thread){
        msg.srcId = _id;
        msg.ack = true;
        if (!msg.ack_id){
                /*TODO: Create better random/unique ack_id?
                ack_id made by multiplying "random" prime numbers with
                message parameters to create unique id per message.
                This way, 2 identical msg will get same id, only if identical*/
                msg.ack_id = 373 * msg.dstId + 113 * msg.floor
                        + 197 * to!int(msg.msgtype) + 131 * msg.bid;
        }
        Udp_msg_owner msg_owner;
        msg_owner.msg = msg;
        msg_owner.owner_thread = msg_owner_thread;
        safeTxThread.send(msg_owner);
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
    auto network_peers_thread = spawn(&network_peers.init_network_peers, broadcastport, _id, interval, timeout);
    txThread                  = spawn(&Udp_tx);
    rxThread                  = spawn(&Udp_rx);
    safeTxThread              = spawn(&udp_safe_send_handler);

    Thread.sleep(250.msecs); //wait for all threads to start...

    while(true){
        receive(
            (PeerList p){
                /*TODO: Handle PeerList updates
                peerlist should be sent to safe_send_handler */
                safeTxThread.send(p);
                writeln("Received peerlist: ", p);
            },
            (Udp_msg msg){
                /*TODO: Handle UDP message*/

                /*udp_ack_confirm probably shouldnt be called here like this
                For testing purposes only.  */
                if((msg.ack) && ((msg.dstId == _id) || (msg.dstId || 255))) {
                    udp_ack_confirm(msg);
                }

                switch(msg.msgtype)
                {
                    case 'e':
                        /*TODO: Handle external orders*/
                        if (msg.dstId == _id || msg.dstId == 255){
                                //writeln("Received message type ", 'e', " from id ", msg.srcId);
                        }
                        break;
                    case 'i':
                        /*TODO: Handle internal orders*/
                        if (msg.dstId == _id || msg.dstId == 255){
                                //writeln("Received message type ", 'i', " from id ", msg.srcId);
                        }
                        break;
                    case 'a':
                        /*TODO: Handle ack messages*/
                        if (msg.dstId == _id || msg.dstId == 255){
                                safeTxThread.send(msg);
                                writeln("Received message type ", 'a', " from id ", msg.srcId);
                        }
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
