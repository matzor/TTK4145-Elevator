import std.stdio, std.container;
import std.algorithm;
import std.array,std.range;
import bidding;
import concurrency;

class Order{


}

void main(){
	spawn(bidding_main(1, 1));
	while(true){
		
	}
}
