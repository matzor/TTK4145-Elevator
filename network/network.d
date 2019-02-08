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
private __gshared ushort        com_port        = 19667;       //GLOBAL VARIABLE SHAME SHAME SHAME
private __gshared size_t        bufSize         = 1024;
private __gshared int           recvFromSelf    = 0;
private __gshared int           interval_ms     = 100;
private __gshared Duration      interval;
private __gshared int           timeout_ms      = 550;
private __gshared Duration      timeout;
private __gshared string        id_str          = "default";
private __gshared ubyte         _id;

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

            //Doesn't work for some reason
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
        /*

        */
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
            //writeln("Found peer ", buf[0]);
        }https://github.com/TTK4145-students-2019/project-group-62

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
    ubyte srcId;
    ubyte dstId;
    string msg; //TODO: For testing only, remove this
    //TODO: msg type
    //TODO: Order (internal/external)
    //TODO: cost/bid
    //TODO: Fines
    //TODO: ACK yes/no
}

struct Udp_safe_msg{
    Udp_msg msg;
}

void UDP_tx(Tid rxTid){
    /*TODO: Implement transmit function
    implemented skeleton code*/

    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr    = new InternetAddress("255.255.255.255", com_port);
    auto    sock    = new UdpSocket();

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    while(true){
        receive(
          (Udp_msg msg){
            sock.sendTo(msg.msg, addr);
            },

            (Udp_safe_msg msg){
              //TODO: implement send function with ack confirmation
            }
            );
          }

    }catch(Throwable t){ t.writeln; throw t; }
}


void UDP_rx(Tid txTid){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr    = new InternetAddress("255.255.255.255", com_port);
    auto    sock    = new UdpSocket();
    ubyte[] buf     = new ubyte[](bufSize);

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.bind(addr);

    while(true){
        auto n = sock.receive(buf);
        if (n>0) {
            Udp_msg msg;
            msg.msg = "HEY I GOT A MESSAGE!";
            //txTid.send(msg);
            writeln(msg.msg);
        }
    }

    } catch(Throwable t){ t.writeln; throw t; }
}

void networkMain(){
    network_init();
    auto broadcastTxThread = spawn(&broadcast_tx);
    auto broadcastRxThread = spawn(&broadcast_rx);
    Tid txThread, rxThread;

    txThread = spawn(&UDP_tx, rxThread);
    rxThread = spawn(&UDP_rx, txThread);

    Thread.sleep(500.msecs); //wait for all threads to start...

    Udp_msg msg;
    msg.msg = "This is a message";
    txThread.send(msg);

    while(true){
        receive(
            (PeerList p){
                writeln("Received peerlist: ", p);
            }
        );
    }
}

void main(){
    networkMain();
}
