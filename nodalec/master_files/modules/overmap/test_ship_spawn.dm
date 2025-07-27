// Test verb for spawning ships
/client/verb/test_spawn_ship()
	set name = "Test Spawn Ship"
	set category = "Debug"
	
	if(!check_rights(R_DEBUG))
		return
		
	var/ship_config = "_maps/nodalec/configs/independent_alone.json"
	to_chat(src, "Checking config: [ship_config]")
	to_chat(src, "File exists: [fexists(ship_config)]")
	to_chat(src, "Current maxz: [world.maxz]")
	
	if(fexists(ship_config))
		to_chat(src, "Calling spawn_player_ship...")
		log_world("TEST: About to call spawn_player_ship")
		var/result = SSovermap.spawn_player_ship(ship_config, mob)
		log_world("TEST: spawn_player_ship returned: [result]")
		to_chat(src, "Spawn result: [result]")
		to_chat(src, "New maxz: [world.maxz]")
	else
		to_chat(src, "Ship config not found: [ship_config]")

/client/verb/test_create_ship_box()
	set name = "Test Create Ship Box"
	set category = "Debug"
	
	if(!check_rights(R_DEBUG))
		return
		
	var/ship_config = "_maps/nodalec/configs/independent_alone.json"
	if(fexists(ship_config))
		SSovermap.create_ship_box(ship_config, mob)
		to_chat(src, "Ship box created!")
	else
		to_chat(src, "Ship config not found: [ship_config]")