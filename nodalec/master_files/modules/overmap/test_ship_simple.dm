// Simple test ship for overmap interaction
/obj/structure/overmap/ship/test
	name = "test vessel"
	desc = "A simple test ship for overmap interaction."
	
/obj/structure/overmap/ship/test/Initialize(mapload)
	. = ..()
	// Create a basic ship without template
	if(!source_template)
		// Set basic properties
		display_name = "Test Ship"
		map_name = "test_ship_map"
		state = OVERMAP_SHIP_FLYING
		mass = 100
		est_thrust = 50
		speed = list(0, 0)
		
		// Initialize map objects if needed
		if(render_map)
			cam_screen = new
			cam_screen.name = "screen"
			cam_screen.assigned_map = map_name
			cam_screen.del_on_map_removal = FALSE
			cam_screen.screen_loc = "[map_name]:1,1"
			
			cam_background = new
			cam_background.assigned_map = map_name
			cam_background.del_on_map_removal = FALSE
			update_screen()
		
		SSovermap.simulated_ships += src

// Admin verb to spawn test ship
/client/proc/spawn_test_ship()
	set name = "Spawn Test Ship"
	set category = "Admin.Game"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		to_chat(src, "No free overmap space found!")
		return
		
	var/obj/structure/overmap/ship/test/test_ship = new(spawn_turf)
	to_chat(src, "Test ship spawned at [spawn_turf] ([spawn_turf.x], [spawn_turf.y])")
	
	// Try to connect nearby helm consoles to this ship
	for(var/obj/machinery/computer/helm/helm in world)
		if(!helm.current_ship && get_dist(helm, spawn_turf) < 50) // Arbitrary distance
			helm.current_ship = test_ship
			to_chat(src, "Connected helm console at [helm.loc] to test ship")
			break

// Simple proc to connect helm to nearest ship
/obj/machinery/computer/helm/proc/connect_to_nearest_ship()
	if(current_ship)
		return current_ship
		
	// Find nearest overmap ship
	var/obj/structure/overmap/ship/nearest_ship
	var/min_dist = INFINITY
	
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		var/dist = get_dist(src, ship)
		if(dist < min_dist)
			min_dist = dist
			nearest_ship = ship
	
	if(nearest_ship)
		current_ship = nearest_ship
		say("Connected to [nearest_ship.name]")
		return nearest_ship
	
	return null