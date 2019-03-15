ulong calculate_own_cost(bool fine){
	/** COST CALCULATING TABLE:
		-Add:
			*|Order_floor-Current_floor| +diff
			*Dir=! order_dir  +10 
			*Fine +100
		-If tie, lowest ID wins, this a part of assoc_array and min value.
	**/
	int current_floor;
	int order_floor;
	int current_direction;
	int order_direction;
	//TODO: Get current floor and direction from floor sensor thread. 
	int delta_floor=current_floor-order_floor;
	if(delta_floor<0){
		 delta_floor = -delta_floor;
	}
	ulong own_cost=0;
	own_cost+=delta_floor;
	if(current_direction != order_direction){
		own_cost+=10;
	}
	if(fine){
		own_cost+=100;
	}	
	return own_cost;
}

ubyte calculate_winner(ulong[ubyte] cost_list){ //Return ID of winner.
	import	assoc_array_helper;
	return key_of_min_value(cost_list);
} 

