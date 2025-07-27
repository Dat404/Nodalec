// Admin commands for overmap testing

/client/proc/overmap_create_test_ship()
	set name = "Create Test Ship"
	set category = "Admin.Overmap"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		to_chat(src, "<span class='warning'>No free overmap space found!</span>")
		return
		
	var/obj/structure/overmap/ship/test/test_ship = new(spawn_turf)
	to_chat(src, "<span class='notice'>Test ship '[test_ship.name]' spawned at ([spawn_turf.x], [spawn_turf.y]) on overmap.</span>")
	
	// Log the creation
	log_admin("[key_name(src)] created test ship at overmap coordinates ([spawn_turf.x], [spawn_turf.y])")

/client/proc/overmap_goto_ship()
	set name = "Goto Overmap Ship"
	set category = "Admin.Overmap"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/list/ship_list = list()
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		ship_list[ship.name] = ship
		
	if(!length(ship_list))
		to_chat(src, "<span class='warning'>No ships found on overmap!</span>")
		return
		
	var/choice = input(src, "Select ship to teleport to:", "Goto Ship") as null|anything in ship_list
	if(!choice)
		return
		
	var/obj/structure/overmap/ship/selected_ship = ship_list[choice]
	if(!selected_ship)
		return
		
	mob.forceMove(get_turf(selected_ship))
	to_chat(src, "<span class='notice'>Teleported to [selected_ship.name] at overmap coordinates ([selected_ship.x], [selected_ship.y]).</span>")

/client/proc/overmap_list_ships()
	set name = "List Overmap Ships"
	set category = "Admin.Overmap"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/list/output = list("<b>Overmap Ships:</b>")
	
	if(!length(SSovermap.simulated_ships))
		output += "No ships found on overmap."
	else
		for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
			var/status = "Unknown"
			switch(ship.state)
				if(OVERMAP_SHIP_FLYING)
					status = "Flying"
				if(OVERMAP_SHIP_IDLE)
					status = "Docked"
				if(OVERMAP_SHIP_DOCKING)
					status = "Docking"
				if(OVERMAP_SHIP_UNDOCKING)
					status = "Undocking"
			
			var/speed_info = ship.is_still() ? "Stationary" : "Speed: [ship.get_speed()]"
			output += "• [ship.name] - [status] - Position: ([ship.x], [ship.y]) - [speed_info]"
	
	to_chat(src, output.Join("<br>"))

/client/proc/overmap_connect_helm()
	set name = "Connect Helm to Ship"
	set category = "Admin.Overmap"
	
	if(!check_rights(R_ADMIN))
		return
		
	// Find helm consoles
	var/list/helm_list = list()
	for(var/obj/machinery/computer/helm/helm in world)
		helm_list["[helm] at [helm.loc]"] = helm
		
	if(!length(helm_list))
		to_chat(src, "<span class='warning'>No helm consoles found!</span>")
		return
		
	var/helm_choice = input(src, "Select helm console:", "Connect Helm") as null|anything in helm_list
	if(!helm_choice)
		return
		
	var/obj/machinery/computer/helm/selected_helm = helm_list[helm_choice]
	
	// Find ships
	var/list/ship_list = list("Disconnect" = null)
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		ship_list[ship.name] = ship
		
	if(length(ship_list) == 1)
		to_chat(src, "<span class='warning'>No ships found on overmap!</span>")
		return
		
	var/ship_choice = input(src, "Select ship to connect:", "Connect Helm") as null|anything in ship_list
	if(isnull(ship_choice))
		return
		
	var/obj/structure/overmap/ship/selected_ship = ship_list[ship_choice]
	selected_helm.current_ship = selected_ship
	
	if(selected_ship)
		to_chat(src, "<span class='notice'>Connected [selected_helm] to [selected_ship.name].</span>")
		selected_helm.say("Connected to [selected_ship.name]")
	else
		to_chat(src, "<span class='notice'>Disconnected [selected_helm] from ship.</span>")
		selected_helm.say("Ship connection terminated")