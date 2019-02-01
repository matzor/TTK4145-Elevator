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
        core.thread;

private __gshared ushort        broadcastport   = 19668;
private __gshared size_t        bufSize         = 1024;
private __gshared int           recvFromSelf    = 0;
private __gshared int           interval_ms     = 100;
private __gshared int           interval_timeout= 5;

struct AliveMsg {
    string  ip;
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
        );
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
    auto addr = new InternetAddress(11111);
    auto hostName = addr.toHostNameString;
    auto serverip = getAddress(hostName)[1].toString;
    serverip= serverip[0 .. serverip.length - 2]; //removes ':0', can this be done more elegant?
    writeln(serverip);

    AliveMsg alive;
    alive.ip = serverip;

    Address broadcast = new InternetAddress("255.255.255.255", broadcastport);
    auto sock = UDP_init(broadcastport);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    while(true){
        writeln("Broadcasting IP: ", serverip);
        sock.sendTo(serverip, broadcast);
        Thread.sleep(interval_ms.msecs);
    }
}

void broadcast_rx(){
    auto sock = UDP_init(broadcastport);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.BROADCAST, 1);
    sock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    sock.Socket.setOption(SocketOptionLevel.SOCKET,
    SocketOption.RCVTIMEO, dur!"seconds"(interval_timeout));   //sets timeout on receive
    char[1024] receiveBuffer = "";
    writeln("Ready to listen on port ", broadcastport);

    AliveMsg alive; //USE A LIST OR SOMETHING!
    string[] networkConnections;
    while(true){
        auto bufferLength = sock.receive(receiveBuffer);
        if (bufferLength >= 0){
            //Not alone
            alive.ip = receiveBuffer[0 .. cast(int)bufferLength].idup();

            if (networkConnections.length <= 0){
                networkConnections[0] = alive.ip;
                spawn(&heartBeatMonitor, alive.ip);
            }
            bool exists = false;
            for (int i = 0; i < networkConnections.length; i++){
                if (networkConnections[i] == alive.ip){exists = true; break;}
            }
            if (!exists){
                networkConnections[networkConnections.length] = alive.ip;
                spawn(&heartBeatMonitor, alive.ip);
            }
            ownerTid.send(alive);
        }
        else{
            //All alone
        }
    }
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
