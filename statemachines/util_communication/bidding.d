int calculate_own_cost(int fine){
	/** COST CALCULATING TABLE:
		-Add:
			*|Order_floor-Current_floor| +diff
			*Fine +100
			*Dir=! order_dir  +10 
		-If tie, first sender wins. TODO: implement this.
	**/

	//TODO: Get current floor and direction from floor sensor thread.
	//TODO: Calculate cost like in table above.
	//TODO: Return cost.
}

int calculate_winner(int own_cost, int others_cost[]){ //Return ID of winner. //TODO: Fix how list input works.
	//TODO: Compare own cost to others cost.
	//TODO: return ID of winner. 
} 
