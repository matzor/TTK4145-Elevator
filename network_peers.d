import  std.concurrency,
        std.datetime,
        std.stdio,
        std.socket;

private __gshared ushort        broadcastport;
private __gshared ubyte         _id;
private __gshared Duration      broadcast_interval;
private __gshared Duration      receive_timeout;


struct TxEnable {
    bool enable;
    alias enable this;
}

struct PeerList {
    immutable(ubyte)[] peers;
    alias peers this;
}

void init_network_peers(ushort port, ubyte id, Duration interval, Duration timeout){
    broadcastport = port; _id = id; broadcast_interval = interval; receive_timeout = timeout;
    auto broadcastTxThread = spawn(&broadcast_tx);
    auto broadcastRxThread = spawn(&broadcast_rx, ownerTid);
    while(true){
        receive(
                (Variant v) {}
            );
    }
}

/*Continually broadcasts own id on designated (broadcast)port every
interval_ms timsetep */
void broadcast_tx(){
    scope(exit) writeln(__FUNCTION__, " died");
    try {

    auto    addr                    = new InternetAddress("255.255.255.255", broadcastport);
    auto    sock                    = new UdpSocket();
    ubyte[1] buf                    = [_id];

    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);

    bool txEnable = true;
    writeln(__FUNCTION__, " started");
    writeln("Broadcasting id: ", buf);
    while(true){
        receiveTimeout(broadcast_interval,
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
from peer before timeout_ms, peer is removed from list of connections.
Heavily inspired by D network module example from klasbos github, excersise 4*/
void broadcast_rx(Tid parent_thread_id){
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
        SocketOption.RCVTIMEO, receive_timeout);

    sock.bind(addr);
    writeln(__FUNCTION__, " started");

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
            if(Clock.currTime - v > receive_timeout){
                listHasChanges = true;
                lastSeen.remove(k);
                writeln("Lost peer ", k);
            }
        }

        if(listHasChanges){
            writeln("Peerlist changed!");
            parent_thread_id.send(PeerList(lastSeen.keys.idup));
        }
    }
    } catch(Throwable t){ t.writeln; throw t; }
}
