ubyte key_of_min_value(int[ubyte] list){
	ulong min_val=429496729;
	ubyte min_key;
	foreach(key; list.keys){
		if(min_val>list[key]){
			min_val=list[key];
			min_key=key;
		}
	}
	return min_key;
}
