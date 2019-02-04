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
        std.datetime;

private __gshared ushort        broadcastport   = 19668;
private __gshared ushort        peerport        = 19667;
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
            "net_peer_port",            &peerport,
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

void UDP_tx(){
    /*TODO: Implement transmit function
    NB: Messages must be ack'ed! (maybe not if peerlist empty...)*/
}

void UDP_rx(){
    //TODO: Implement receive function
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
