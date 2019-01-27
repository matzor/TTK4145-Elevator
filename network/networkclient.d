import std.stdio;
import std.socket;
import core.thread;

ushort SERVERBROADCASTPORT = 30000;
ushort TRANSMITPORT = 30001;

Socket UDP_init(ushort portNumber){
  Socket server = new UdpSocket();
  server.bind(new InternetAddress(portNumber));
  return server;
}

void main(){

  //Listen for server broadcasting ip on broadcastport
  auto server = UDP_init(SERVERBROADCASTPORT);
  char[100] receiveBuffer = "";
  long bufferLength = -1;
  writeln("Ready to listen on port ", SERVERBROADCASTPORT);
  while(bufferLength <= 0){
    bufferLength = server.receive(receiveBuffer);
    writeln("Recieved on port ", SERVERBROADCASTPORT, ": ", receiveBuffer);
  }

  //Convert received string into ip address and open new socket
  auto serveripString = receiveBuffer[0 .. bufferLength-2];
  writeln("Initiating transmission to ", serveripString);

  auto sendingSocket = UDP_init(TRANSMITPORT);
  auto remoteAddress = new InternetAddress(serveripString, TRANSMITPORT);

  //send heartbeat every second
  while(true){
    writeln("Sending heartbeat... ");
    sendingSocket.sendTo("HELLO SERVER!", remoteAddress);
    Thread.sleep(1.seconds);
  }
  writeln("Exited");
}
