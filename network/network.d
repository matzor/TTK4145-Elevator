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

struct AliveMsg {
    string  ip;
}

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

    } catch(Exception e){
        writeln("Unable to load net_bcast config:\n", e.msg);
    }
}

Socket UDP_init(ushort portNumber){
  Socket server = new UdpSocket();
  server.bind(new InternetAddress(portNumber));
  return server;
}

void broadcast_tx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {
    /*
    auto addr = new InternetAddress(11111);
    auto hostName = addr.toHostNameString;
    auto serverip = getAddress(hostName)[1].toString;
    serverip= serverip[0 .. serverip.length - 2]; //removes ':0', can this be done more elegant?
    writeln(serverip);
    */

    auto    addr                    = new InternetAddress("255.255.255.255", broadcastport);
    auto    sock                    = new UdpSocket();
    ubyte[1] buf                    = [id];

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    bool txEnable = true;
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

    auto sock = UDP_init(broadcastport);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.Socket.setOption(SocketOptionLevel.SOCKET,
    SocketOption.RCVTIMEO, timeout);   //sets timeout on receive

    ubyte[1]            buf;
    SysTime[ubyte]      lastSeen;
    bool                listHasChanges;

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
            }
        }

        if(listHasChanges){
            ownerTid.send(PeerList(lastSeen.keys.idup));
        }
    }
    } catch(Throwable t){ t.writeln; throw t; }
}


void heartBeatMonitor(string ip){}

void networkMain(){
    network_init();
    auto broadcastThread = spawn(&broadcast_tx);

    while(true){
        receive(
            (AliveMsg a){
                writeln("Received HelloMsg: ", a);
            }
        );
    }
}

void main(){
    networkMain();
}
