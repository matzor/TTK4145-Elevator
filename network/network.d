import  std.array,
        std.algorithm,
        std.concurrency,
        std.conv,
        std.file,
        std.getopt,
        std.meta,
        std.socket,
        std.stdio,
        std.string,
        std.traits,
        std.typecons,
        std.datetime,
        core.thread;

private __gshared ushort        broadcastport   = 19668;
private __gshared ushort        peerport        = 19667;
private __gshared size_t        bufSize         = 1024;
private __gshared int           recvFromSelf    = 0;
private __gshared int           interval_ms     = 100;
private __gshared Duration      interval;
private __gshared int           timeout_ms      = 350;
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
        configContents = readText("net.con").split;
        getopt( configContents,
            std.getopt.config.passThrough,
            "net_bcast_port",           &broadcastport,
            "net_bcast_bufsize",        &bufSize,
            "net_bcast_recvFromSelf",   &recvFromSelf,
            "net_peer_port",            &peerport,
            "net_peer_timeout",         &timeout_ms,
            "net_peer_interval",        &interval_ms,
            "net_peer_id",              &id_str
        );

        timeout = timeout_ms.msecs;
        interval = interval_ms.msecs;

        if(id_str == "default"){
            _id = new TcpSocket(new InternetAddress("google.com", 80))
                .localAddress
                .toAddrString
                .splitter('.')
                .array[$-1]
                .to!ubyte;
        } else {
            _id = id_str.to!ubyte;
        }
        writeln("Network init complete");

    } catch(Exception e){
        writeln("Unable to load net_bcast config:\n", e.msg);
    }
}

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


void networkMain(){
    network_init();
    auto broadcastTxThread = spawn(&broadcast_tx);
    auto broadcastRxThread = spawn(&broadcast_rx);
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
