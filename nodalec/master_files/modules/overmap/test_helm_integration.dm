// Test integration for helm console with overmap

/obj/structure/overmap/ship/test_ship
	name = "test vessel"
	desc = "A test ship for helm console integration."

/obj/structure/overmap/ship/test_ship/Initialize(mapload)
	. = ..()
	name = "Test Ship"
	mass = 100
	acceleration_speed = 0.02
	speed = list(0, 0)
	state = OVERMAP_SHIP_FLYING
	return INITIALIZE_HINT_NORMAL

// Simple planet for testing interactions
/obj/structure/overmap/planet/test_planet
	name = "test planet"
	desc = "A simple planet for testing helm console interactions."
	icon_state = "planet"
	color = "#00AA00"

/obj/structure/overmap/planet/test_planet/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	to_chat(user, "<span class='notice'>You interact with the test planet. This is a simple test interaction.</span>")
	return "Test interaction completed."

// Admin verb to create test ship
/client/proc/create_test_ship()
	set name = "Create Test Ship"
	set category = "Admin"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/turf/target_turf = SSovermap.get_unused_overmap_square()
	if(!target_turf)
		to_chat(src, "No free space on overmap!")
		return
		
	var/obj/structure/overmap/ship/test_ship/new_ship = new(target_turf)
	to_chat(src, "Created test ship at [target_turf.x], [target_turf.y]")
	
	// Create shuttle area and docking port
	var/area/shuttle/test_shuttle/test_area = new()
	test_area.name = "Test Ship Bridge"
	
	var/turf/shuttle_turf = locate(50, 50, usr.z)
	if(shuttle_turf)
		// Create shuttle floor and area
		for(var/x in 0 to 2)
			for(var/y in 0 to 2)
				var/turf/T = locate(shuttle_turf.x + x, shuttle_turf.y + y, shuttle_turf.z)
				T.ChangeTurf(/turf/open/floor/plasteel)
				T.ChangeArea(test_area)
		
		// Create docking port
		var/obj/docking_port/mobile/test_port = new(shuttle_turf)
		test_port.name = "Test Ship"
		test_port.shuttle_areas = list(test_area)
		test_port.width = 3
		test_port.height = 3
		
		new_ship.shuttle = test_port
		SSovermap.controlled_ships += new_ship
		
		// Place helm console
		var/obj/machinery/computer/helm/console = new(shuttle_turf)
		console.connected_ship = new_ship
		
		to_chat(src, "Created shuttle area and helm console at [shuttle_turf.x], [shuttle_turf.y], [shuttle_turf.z]")
	
	// Also create a test planet nearby for interaction testing
	var/turf/planet_turf = SSovermap.get_unused_overmap_square()
	if(planet_turf)
		new /obj/structure/overmap/planet/test_planet(planet_turf)
		to_chat(src, "Created test planet at [planet_turf.x], [planet_turf.y] for interaction testing")

/area/shuttle/test_shuttle
	name = "Test Shuttle"
	requires_power = FALSE

// Admin verb to create test planet separately
/client/proc/create_test_planet()
	set name = "Create Test Planet"
	set category = "Admin"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/turf/target_turf = SSovermap.get_unused_overmap_square()
	if(!target_turf)
		to_chat(src, "No free space on overmap!")
		return
		
	new /obj/structure/overmap/planet/test_planet(target_turf)
	to_chat(src, "Created test planet at [target_turf.x], [target_turf.y]")