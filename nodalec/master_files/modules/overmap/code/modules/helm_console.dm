/obj/machinery/computer/helm
	name = "helm control console"
	desc = "Used to view or control the ship."
	icon_screen = "navigation"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/helm
	light_color = LIGHT_COLOR_CYAN
	clicksound = null

	/// All users currently using this
	var/list/concurrent_users = list()
	/// Is this console view only?
	var/viewer = FALSE
	/// The ship this console is connected to
	var/obj/structure/overmap/ship/connected_ship
	/// Current throttle percentage
	var/throttle_percentage = 50

/obj/machinery/computer/helm/ui_interact(mob/living/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		var/user_ref = REF(user)
		var/is_living = isliving(user)
		if(is_living)
			concurrent_users += user_ref
			if(length(concurrent_users) == 1)
				playsound(src, 'sound/machines/terminal_on.ogg', 25, FALSE)
				use_power(active_power_usage)
		ui = new(user, src, "HelmConsole", name)
		ui.open()

/obj/machinery/computer/helm/ui_data(mob/user)
	. = list()
	.["otherInfo"] = list()
	
	// Find our ship
	var/obj/structure/overmap/ship/our_ship = get_overmap_ship()
	if(!our_ship)
		.["x"] = 0
		.["y"] = 0
		.["docking"] = FALSE
		.["docked"] = null
		.["course"] = "0°"
		.["heading"] = "0°"
		.["speed"] = 0
		.["eta"] = 0
		.["estThrust"] = 0
		.["engineInfo"] = list()
		.["burnDirection"] = 0
		.["burnPercentage"] = 50
		.["rotating"] = 0
		.["calibrating"] = FALSE
		.["aiControls"] = FALSE
		.["arpa_ships"] = list()
		return
	
	// Get nearby overmap objects within sensor range
	var/sensor_range = 4 // Default sensor range
	for(var/obj/structure/overmap/obj in view(sensor_range, our_ship))
		if(obj == our_ship)
			continue
		var/list/other_data = list(
			name = obj.name,
			ref = REF(obj)
		)
		.["otherInfo"] += list(other_data)
	
	// Ship position and status
	.["x"] = our_ship.x
	.["y"] = our_ship.y
	.["docking"] = (our_ship.state == OVERMAP_SHIP_DOCKING)
	.["docked"] = our_ship.docked ? our_ship.docked.name : null
	
	// Movement data
	var/heading_angle = dir2angle(our_ship.get_heading())
	.["course"] = "[heading_angle]°"
	.["heading"] = "[heading_angle]°"
	.["speed"] = our_ship.get_speed()
	.["eta"] = our_ship.get_eta()
	
	// Engine data
	our_ship.refresh_engines()
	.["estThrust"] = our_ship.est_thrust
	.["engineInfo"] = list()
	
	// Current burn settings
	.["burnDirection"] = get_burn_direction(our_ship)
	.["burnPercentage"] = throttle_percentage
	.["rotating"] = 0
	.["calibrating"] = FALSE
	.["aiControls"] = FALSE
	.["arpa_ships"] = list()

/obj/machinery/computer/helm/ui_static_data(mob/user)
	. = list()
	.["isViewer"] = viewer
	// Map reference for overmap display
	var/obj/structure/overmap/ship/our_ship = get_overmap_ship()
	if(our_ship && our_ship.render_map)
		.["mapRef"] = our_ship.map_name
	else
		.["mapRef"] = "helm_console_map"
	
	// Get ship info
	var/obj/structure/overmap/ship/our_ship = get_overmap_ship()
	if(our_ship)
		.["shipInfo"] = list(
			name = our_ship.name,
			class = our_ship.source_template ? our_ship.source_template.name : "Unknown Class",
			mass = our_ship.mass,
			sensor_range = 4
		)
		.["canFly"] = (our_ship.state == OVERMAP_SHIP_FLYING || our_ship.state == OVERMAP_SHIP_IDLE)
	else
		.["shipInfo"] = list(
			name = "No Ship Connected",
			class = "Unknown Class",
			mass = 0,
			sensor_range = 0
		)
		.["canFly"] = FALSE
	
	.["aiUser"] = issilicon(user)

/obj/machinery/computer/helm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(viewer)
		return
	. = TRUE

	var/obj/structure/overmap/ship/our_ship = get_overmap_ship()
	if(!our_ship)
		to_chat(usr, "<span class='warning'>No ship connected to this console!</span>")
		return

	switch(action)
		if("act_overmap")
			var/target_ref = params["ship_to_act"]
			var/obj/structure/overmap/target = locate(target_ref)
			if(target)
				our_ship.overmap_object_act(usr, target)
			return
		if("change_heading")
			var/new_direction = text2num(params["dir"])
			if(our_ship.state != OVERMAP_SHIP_FLYING)
				to_chat(usr, "<span class='warning'>Ship must be in flight mode to change heading!</span>")
				return
			if(new_direction == -1) // Stop command
				our_ship.decelerate(our_ship.acceleration_speed)
			else
				our_ship.burn_engines(new_direction, throttle_percentage)
			return
		if("set_throttle")
			var/new_throttle = text2num(params["throttle"])
			if(new_throttle >= 1 && new_throttle <= 100)
				throttle_percentage = new_throttle
			return
		if("stop")
			if(our_ship.state != OVERMAP_SHIP_FLYING)
				to_chat(usr, "<span class='warning'>Ship must be in flight mode to stop!</span>")
				return
			our_ship.decelerate(our_ship.acceleration_speed)
			return
		if("undock")
			if(!our_ship.docked)
				to_chat(usr, "<span class='warning'>Ship is not docked!</span>")
				return
			var/result = our_ship.undock()
			to_chat(usr, "<span class='notice'>[result]</span>")
			return
		if("dock_empty")
			if(our_ship.state != OVERMAP_SHIP_FLYING)
				to_chat(usr, "<span class='warning'>Ship must be in flight mode to dock!</span>")
				return
			if(!our_ship.is_still())
				to_chat(usr, "<span class='warning'>Ship must be stationary to dock!</span>")
				return
			our_ship.dock_in_empty_space(usr)
			return
		if("rename_ship")
			var/new_name = params["newName"]
			if(our_ship.set_ship_name(new_name))
				to_chat(usr, "<span class='notice'>Ship renamed to [new_name].</span>")
			else
				to_chat(usr, "<span class='warning'>Failed to rename ship. Check cooldown or name validity.</span>")
			return
		if("connect_ship")
			// Try to find any ship and connect to it
			for(var/obj/structure/overmap/ship/ship in SSovermap.controlled_ships)
				connected_ship = ship
				to_chat(usr, "<span class='notice'>Force connected to [ship.name].</span>")
				return
			to_chat(usr, "<span class='warning'>No ships found in system!</span>")
			return

/obj/machinery/computer/helm/verb/debug_connect()
	set name = "Debug Connect"
	set category = null
	set src in view(1)
	
	if(!usr.client.holder)
		return
		
	for(var/obj/structure/overmap/ship/ship in SSovermap.controlled_ships)
		connected_ship = ship
		to_chat(usr, "Connected to [ship.name]")
		return
	to_chat(usr, "No ships found")

/obj/machinery/computer/helm/ui_close(mob/user)
	var/user_ref = REF(user)
	var/is_living = isliving(user)
	concurrent_users -= user_ref
	if(!length(concurrent_users) && is_living)
		playsound(src, 'sound/machines/terminal_off.ogg', 25, FALSE)
		use_power(0)

/// Get the overmap ship this console is connected to
/obj/machinery/computer/helm/proc/get_overmap_ship()
	if(connected_ship && !QDELETED(connected_ship))
		return connected_ship
	
	// Try to auto-connect to a ship in our area
	var/area/our_area = get_area(src)
	for(var/obj/structure/overmap/ship/ship in SSovermap.controlled_ships)
		if(!ship.shuttle)
			continue
		for(var/area/ship_area in ship.shuttle.shuttle_areas)
			if(ship_area == our_area)
				connected_ship = ship
				log_world("Helm console connected to ship: [ship.name]")
				return ship
	log_world("Helm console failed to find ship in area: [our_area.name]")
	return null

/// Get current burn direction for UI display
/obj/machinery/computer/helm/proc/get_burn_direction(obj/structure/overmap/ship/ship)
	if(!ship || ship.is_still())
		return 0
	return ship.get_heading()

/// Convert direction to angle for display
/obj/machinery/computer/helm/proc/dir2angle(direction)
	switch(direction)
		if(NORTH)
			return 0
		if(NORTHEAST)
			return 45
		if(EAST)
			return 90
		if(SOUTHEAST)
			return 135
		if(SOUTH)
			return 180
		if(SOUTHWEST)
			return 225
		if(WEST)
			return 270
		if(NORTHWEST)
			return 315
		else
			return 0

/obj/item/circuitboard/computer/helm
	name = "helm console circuit board"
	build_path = /obj/machinery/computer/helm