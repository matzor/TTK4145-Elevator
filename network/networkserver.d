import std.stdio;
import std.socket;
import std.concurrency;
import core.thread;

enum ushort SERVERBROADCASTPORT = 30000;
enum ushort TRANSMITPORT = 30001;

struct IsAlive{}
struct IsDead{}

Socket UDP_init(ushort portNumber){
  Socket server = new UdpSocket();
  server.bind(new InternetAddress(portNumber));
  return server;
}

//Broadcasts host ip over local network
void broadcastOwnIp(){
  auto a = new InternetAddress(30005);
  auto hostName = a.toHostNameString;
  auto serverip = getAddress(hostName); //server hostname
  writeln("Initializing broadcast of IP: ", serverip[1], "... ");
  Address broadcast = new InternetAddress("192.168.1.255", SERVERBROADCASTPORT);
  auto server = UDP_init(SERVERBROADCASTPORT);
  while(true){
    writeln("Broadcasting IP: ", serverip[1]);
    server.sendTo(serverip[1].toString, broadcast);
    Thread.sleep(2.seconds);
  }
}

void receiveMessages(){
  IsAlive alive;
  IsDead dead;
  auto server = UDP_init(TRANSMITPORT);
  server.Socket.setOption(SocketOptionLevel.SOCKET,
    SocketOption.RCVTIMEO, dur!"seconds"(2));   //sets timeout on receive
  char[1024] receiveBuffer = "";
  writeln("Ready to listen on port ", TRANSMITPORT);
  while(true){
    auto bufferLength = server.receive(receiveBuffer);
    if (bufferLength >= 0){
      ownerTid.send(alive);
      writeln("Receieved message: ", receiveBuffer);
    }
    else{
      ownerTid.send(dead);
    }
  }
}

void main(){
  auto broadcastThread = spawn(&broadcastOwnIp);
  auto receiveThread = spawn(&receiveMessages);
  while(1){
    receive(
      (IsAlive alive) {writeln("ITS ALIVE. "); },
      (IsDead dead) {writeln("Connection is dead, RIP. ");}
      );
  }
}
