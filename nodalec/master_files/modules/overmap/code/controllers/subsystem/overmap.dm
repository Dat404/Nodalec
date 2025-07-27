/*
voidcrew TODO:
	SSovermap originally fired to apply the planet effects but these would be way better off just using signals



*/
//Amount of times the overmap generator will attempt to place something before giving up
#define MAX_OVERMAP_PLACEMENT_ATTEMPTS 5
#define MAX_OVERMAP_EVENT_CLUSTERS 8
#define MAX_OVERMAP_EVENTS 70
#define MAX_OVERMAP_PLANETS_TO_SPAWN 5

SUBSYSTEM_DEF(overmap)
	name = "Overmap"
	wait = 10
	init_order = INIT_ORDER_OVERMAP
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_SETUP | RUNLEVEL_GAME

	/// All the existing star systems, it's gonna be atleast 1 including the main system
	var/list/tracked_star_systems = list()

	///List of all overmap objects.
	var/list/overmap_objects = list()
	///List of all simulated ships. All ships in this list are fully initialized.
	var/list/controlled_ships = list()
	///List of spawned outposts. The default spawn location is the first index.
	var/list/outposts = list()

	///List of all dynamic overmap datums
	var/list/dynamic_encounters  = list()
	///List of all events
	var/list/events = list()

	/// The mandatory and default star system
	var/datum/overmap_star_system/default_system

	///Should events be processed
	var/events_enabled = TRUE

	///Whether or not a ship is currently being spawned. Used to prevent multiple ships from being spawned at once.
	var/ship_spawning //TODO: Make a proper queue for this

	///List of all simulated ships
	var/list/simulated_ships = list()
	/// Timer ID of the timer used for telling which stage of an endround "jump" the ships are in
	var/jump_timer
	/// Current state of the jump
	var/jump_mode = 0
	/// Time taken for bluespace jump to begin after it is requested (in deciseconds)
	var/jump_request_time = 6000
	/// Time taken for a bluespace jump to complete after it initiates (in deciseconds)
	var/jump_completion_time = 1200

	var/datum/map_template/shuttle/voidcrew/initial_ship_template
	var/obj/structure/overmap/ship/initial_ship

	/// Centre of the overmap
	var/turf/overmap_centre
	/// Map of tiles at each radius around the sun
	var/list/list/radius_tiles = list()
	///Width/height of the overmap "zlevel"
	var/size = 30



/datum/controller/subsystem/overmap/proc/get_metrics()
	. = list()
	var/list/cust = list()
	cust["overmap_objects"] = length(overmap_objects)
	cust["controlled_ships"] = length(controlled_ships)
	.["custom"] = cust

/datum/controller/subsystem/overmap/proc/create_new_star_system(datum/overmap_star_system/new_starsystem)
	if(length(tracked_star_systems) >= 1)
		WARNING("Attempted to create more than 1 star system. Bugs may occur as this isn't very well supported, you have been warned")
	tracked_star_systems += new_starsystem
	return new_starsystem

/**
 * Creates an overmap object for shuttles, triggers initialization procs for ships
 */
/datum/controller/subsystem/overmap/Initialize(start_timeofday)
	overmap_objects = list()
	controlled_ships = list()
	outposts = list()
	dynamic_encounters = list()
	events = list()

	// Load outpost map on z-level 2
	load_outpost_map()
	
	// Create physical overmap on z-level 3
	create_map()
	setup_sun()
	setup_dangers()
	setup_planets()
	spawn_outpost()
	return SS_INIT_SUCCESS

/datum/controller/subsystem/overmap/proc/spawn_new_star_system(datum/overmap_star_system/system_to_spawn=/datum/overmap_star_system)
	if(istype(system_to_spawn))
		return create_new_star_system(system_to_spawn)
	return create_new_star_system(new system_to_spawn)

/datum/controller/subsystem/overmap/fire()
	return
/*
 * Bluespace jump procs
 */

/**
 * ## request_jump
 *
 * Requests a bluespace jump, which, after jump_request_time deciseconds, will initiate a bluespace jump.
 *
 * Arguments:
 * * modifiers - (Optional) Modifies the length of the jump request time (defaults to 1)
 */
/datum/controller/subsystem/overmap/proc/request_jump(modifier = 1)
	jump_mode = BS_JUMP_CALLED
	jump_timer = addtimer(CALLBACK(src, PROC_REF(initiate_jump)), jump_request_time * modifier, TIMER_STOPPABLE)
	priority_announce("Preparing for jump. ETD: [jump_request_time * modifier / 600] minutes.", null, null, "Priority")

/**
 * ##cancel_jump
 *
 * Cancels a currently requested bluespace jump.
 * Can only be done after the jump has been requested, but before the jump has actually begun.
 */
/datum/controller/subsystem/overmap/proc/cancel_jump()
	if(jump_mode != BS_JUMP_CALLED)
		return
	deltimer(jump_timer)
	jump_mode = BS_JUMP_IDLE
	priority_announce("Bluespace jump cancelled.", null, null, "Priority")

/**
 * ##initiate_jump
 *
 * Initiates a bluespace jump, ending the round after a delay of jump_completion_time deciseconds.
 * This cannot be interrupted by conventional means.
 */
/datum/controller/subsystem/overmap/proc/initiate_jump()
	jump_mode = BS_JUMP_INITIATED
	for(var/obj/docking_port/mobile/voidcrew/mobile_port as anything in SSshuttle.mobile_docking_ports)
		mobile_port.hyperspace_sound(HYPERSPACE_WARMUP, mobile_port.shuttle_areas)
		mobile_port.on_emergency_launch()

	priority_announce("Jump initiated. ETA: [jump_completion_time / 600] minutes.", null, null, "Priority")
	jump_timer = addtimer(VARSET_CALLBACK(src, jump_mode, BS_JUMP_COMPLETED), jump_completion_time)

/datum/controller/subsystem/overmap/proc/create_map()
	// Create overmap on z-level 3, bottom-left corner
	var/turf/bottom_left = locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_SOUTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/turf/top_right = locate(OVERMAP_RIGHT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/list/overmap_turfs = block(bottom_left, top_right)
	
	for (var/turf/overmap_turf as anything in overmap_turfs)
		if (overmap_turf.x == OVERMAP_LEFT_SIDE_COORD || overmap_turf.x == OVERMAP_RIGHT_SIDE_COORD || overmap_turf.y == OVERMAP_NORTH_SIDE_COORD || overmap_turf.y == OVERMAP_SOUTH_SIDE_COORD)
			overmap_turf.ChangeTurf(/turf/closed/overmap_edge)
		else
			overmap_turf.ChangeTurf(/turf/open/overmap)
	
	// Set center of overmap
	overmap_centre = locate(OVERMAP_LEFT_SIDE_COORD + round(OVERMAP_SIZE / 2), OVERMAP_SOUTH_SIDE_COORD + round(OVERMAP_SIZE / 2), OVERMAP_Z_LEVEL)

	// MARK: ОЧЕНЬ ВАЖНО!
	// if (generator_type == OVERMAP_GENERATOR_SOLAR)	// TODO: Доделать
	// 	setup_dangers()
	// else
	// 	spawn_events()

	setup_dangers()
	// spawn_ruin_levels()	// TODO: Доделать
	spawn_outpost()
	//spawn_initial_ships()

// MARK: SUN
/datum/controller/subsystem/overmap/proc/setup_sun()
	if(!overmap_centre)
		return
	
	// Create a simple star object
	new /obj/structure/overmap/star/big(overmap_centre)

	var/list/unsorted_turfs = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)
	var/max_ring = 0
	for (var/turf/turf as anything in unsorted_turfs)
		if (istype(turf, /turf/closed/overmap_edge))
			continue
		// the overmap is a square, so we can just use the x and y values to determine the actual ring
		// 2 2 2 2 2
		// 2 1 1 1 2
		// 2 1 X 1 2
		// 2 1 1 1 2
		// 2 2 2 2 2
		var/ring_x = turf.x - (overmap_centre.x + 1)
		var/ring_y = turf.y - (overmap_centre.y + 1)
		var/ring = max(abs(ring_x), abs(ring_y))
		if (!ring)
			continue
		if (ring > max_ring)
			for (var/i in 1 to ring - max_ring)
				radius_tiles += list(list())
			max_ring = ring
		LAZYADDASSOC(radius_tiles, ring, turf)

/datum/controller/subsystem/overmap/proc/get_unused_overmap_square(thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL)))
		if(!turf_to_return)
			continue
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		return turf_to_return
	if (!force)
		turf_to_return = null
	return turf_to_return

/**
 * Returns a random turf in a radius from the star, or a random empty turf if OVERMAP_GENERATOR_RANDOM is the active generator.
 * * thing_to_not_have - The thing you don't want to be in the found tile, for example, an overmap event [/datum/overmap/event].
 * * tries - How many attempts it will try before giving up finding an unused tile..
 * * radius - The distance from the star to search for an empty tile.
 */
/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_radius(radius, thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	if (!radius)
		radius = rand(2, length(radius_tiles) / 2)

	var/turf/turf_to_return

	// turf_to_return = null	// Заглушка. Сбоит на radius_tiles[radius]
	// return turf_to_return

	for (var/_ in 1 to tries)
		turf_to_return = pick(radius_tiles[radius])
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		return turf_to_return

	if (!force)
		turf_to_return = null
		return turf_to_return

// MARK: EVENTS (DANGERS)
/datum/controller/subsystem/overmap/proc/setup_dangers()
	// Create random events across the overmap
	for(var/i in 1 to 8)
		var/turf/event_turf = get_unused_overmap_square()
		if(event_turf)
			var/event_type = pick_weight(GLOB.overmap_event_pick_list)
			new event_type(event_turf)

// MARK: PLANETS
/datum/controller/subsystem/overmap/proc/setup_planets()
	// Create a few simple planets
	for(var/i in 1 to 3)
		var/turf/planet_turf = get_unused_overmap_square()
		if(planet_turf)
			new /obj/structure/overmap/planet(planet_turf)

// TODO - MULTI-Z VLEVELS
/datum/controller/subsystem/overmap/proc/calculate_turf_above(turf/T)
	return

// TODO - MULTI-Z VLEVELS
/datum/controller/subsystem/overmap/proc/calculate_turf_below(turf/T)
	return

// MARK: SHIPS
/**
 * At the start of the game, we want to make sure there is a ship on the overmap for people to join.
 * If there is no default template, we iterate through subtypes and run various checks to see if its a valid ship.
 * When we find a valid template we use it to spawn a ship.
 */
/datum/controller/subsystem/overmap/proc/spawn_initial_ship()
#ifdef UNIT_TESTS
	var/list/remaining_templates = subtypesof(/datum/map_template/shuttle/voidcrew)
	for(var/templates in remaining_templates)
		var/datum/map_template/shuttle/voidcrew/loaded_template = SSshuttle.create_ship(templates)
		if(!initial_ship_template)
			initial_ship_template = loaded_template
		if(!loaded_template)
			log_mapping("[src] failed to load ship [templates].")
#else
	if(!set_initial_ship())
		return
	initial_ship = SSshuttle.create_ship(initial_ship_template)
	if(!initial_ship)
		CRASH("Failed to spawn initial ship.")

	RegisterSignal(initial_ship, COMSIG_PARENT_QDELETING, PROC_REF(handle_initial_ship_deletion))
#endif

/**
 * Attempts to set an initial ship template.
 * If one is already set, this will return out.
 * If a ship is set, initial_ship_template will be set to it, and it will return TRUE, otherwise FALSE.
 */
/datum/controller/subsystem/overmap/proc/set_initial_ship()
	if(initial_ship_template)
		return TRUE

	var/list/remaining_templates = subtypesof(/datum/map_template/shuttle/voidcrew)
	while(!initial_ship_template && LAZYLEN(remaining_templates))
		var/datum/map_template/shuttle/voidcrew/random_template = pick_n_take(remaining_templates)
		if(initial(random_template.abstract) == random_template)
			continue
		if(initial(random_template.enabled) == FALSE)
			continue
		// the first ship will always be an NT or Syndicate one.
		if(initial(random_template.faction_prefix) == NEUTRAL_SHIP)
			continue
		initial_ship_template = random_template
		return TRUE

	stack_trace("Failed to find a valid initial ship template to spawn.")
	return FALSE

/datum/controller/subsystem/overmap/proc/handle_initial_ship_deletion(datum/source)
	SIGNAL_HANDLER

	initial_ship = null
	message_admins("Overmap Starter Ship was deleted. You may want to investigate or spawn a new one!")



	/**
  * Reserves a square dynamic encounter area, and spawns a ruin in it if one is supplied.
  * * on_planet - If the encounter should be on a generated planet. Required, as it will be otherwise inaccessible.
  * * target - The ruin to spawn, if any
  * * ruin_type - The ruin to spawn. Don't pass this argument if you want it to randomly select based on planet type.
  */

// MARK: RUIN
/**
 * ##get_ruin_list
 *
 * Returns the SSmapping list of ruins, according to the given desired ruin type
 *
 * Arguments:
 * * ruin_type - a string, depicting the desired ruin type
 */
/datum/controller/subsystem/overmap/proc/get_ruin_list(ruin_type)
	switch(ruin_type) // temporary because SSmapping needs a refactor to make this any better
		if (ZTRAIT_LAVA_RUINS)
			return SSmapping.lava_ruins_templates
		if (ZTRAIT_ICE_RUINS)
			return SSmapping.ice_ruins_templates
		if (ZTRAIT_JUNGLE_RUINS)
			return SSmapping.jungle_ruins_templates
		if (ZTRAIT_REEBE_RUINS)
			return SSmapping.yellow_ruins_templates
		if (ZTRAIT_SPACE_RUINS)
			return SSmapping.space_ruins_templates
		if (ZTRAIT_BEACH_RUINS)
			return SSmapping.beach_ruins_templates
		if (ZTRAIT_WASTELAND_RUINS)
			return SSmapping.wasteland_ruins_templates

// MARK: DYNAMIC ENCOUNTER
/datum/controller/subsystem/overmap/proc/spawn_dynamic_encounter(datum/overmap/planet/planet_type, ruin = TRUE, ignore_cooldown = FALSE, datum/map_template/ruin/ruin_type)
	log_shuttle("SSOVERMAP: SPAWNING DYNAMIC ENCOUNTER STARTED")
	var/list/ruin_list
	var/datum/map_generator/mapgen
	var/area/target_area
	var/turf/surface = /turf/open/space/basic
	var/datum/weather/weather_controller_type
	var/datum/planet/planet_template
	if(!isnull(planet_type))
		planet_type = new planet_type
		ruin_list = get_ruin_list(planet_type.ruin_type)
		if(!isnull(planet_type.mapgen))
			mapgen = new planet_type.mapgen
		target_area = planet_type.target_area
		surface = planet_type.surface
		weather_controller_type = planet_type.weather_controller_type
		if(!(isnull(planet_type.planet_template)))
			planet_template = new planet_type.planet_template
		qdel(planet_type)

	if(ruin && ruin_list && !ruin_type)
		ruin_type = ruin_list[pick(ruin_list)]
		if(ispath(ruin_type))
			ruin_type = new ruin_type

	var/height = QUADRANT_MAP_SIZE
	var/width = QUADRANT_MAP_SIZE

	var/encounter_name = "Dynamic Overmap Encounter"
	var/datum/map_zone/mapzone = SSmapping.create_map_zone(encounter_name)
	var/datum/virtual_level/vlevel = SSmapping.create_virtual_level(encounter_name, list(ZTRAIT_MINING = TRUE), mapzone, width, height, ALLOCATION_QUADRANT, QUADRANT_MAP_SIZE)

	vlevel.reserve_margin(QUADRANT_SIZE_BORDER)

	if(mapgen) /// If we have a map generator, don't ChangeTurf's in fill_in. Just to ChangeTurf them once again.
		surface = null
	vlevel.fill_in(surface, target_area)

	if(ruin_type)
		var/turf/ruin_turf = locate(rand(
			vlevel.low_x+6 + vlevel.reserved_margin,
			vlevel.high_x-ruin_type.width-6 - vlevel.reserved_margin),
			vlevel.high_y-ruin_type.height-6 - vlevel.reserved_margin,
			vlevel.z_value
			)
		ruin_type.load(ruin_turf)

	if (!isnull(mapgen) && istype(mapgen, /datum/map_generator/planet_generator) && !isnull(planet_template))
		mapgen.generate_terrain(vlevel.get_unreserved_block(), planet_template)
	else
		if (!isnull(mapgen))
			mapgen.generate_terrain(vlevel.get_unreserved_block())

	if(weather_controller_type)
		new weather_controller_type(mapzone)


	// locates the first dock in the bottom left, accounting for padding and the border
	var/turf/primary_docking_turf = locate(
		vlevel.low_x+RESERVE_DOCK_DEFAULT_PADDING+1 + vlevel.reserved_margin,
		vlevel.low_y+RESERVE_DOCK_DEFAULT_PADDING+1 + vlevel.reserved_margin,
		vlevel.z_value
		)
	// now we need to offset to account for the first dock
	var/turf/secondary_docking_turf = locate(
		primary_docking_turf.x+RESERVE_DOCK_MAX_SIZE_LONG+RESERVE_DOCK_DEFAULT_PADDING,
		primary_docking_turf.y,
		primary_docking_turf.z
		)

	//This check exists because docking ports don't like to be deleted.
	var/obj/docking_port/stationary/primary_dock = new(primary_docking_turf)
	primary_dock.dir = NORTH
	primary_dock.name = "\improper Uncharted Space"
	primary_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	primary_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	primary_dock.dheight = 0
	primary_dock.dwidth = 0

	var/obj/docking_port/stationary/secondary_dock = new(secondary_docking_turf)
	secondary_dock.dir = NORTH
	secondary_dock.name = "\improper Uncharted Space"
	secondary_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	secondary_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	secondary_dock.dheight = 0
	secondary_dock.dwidth = 0

	return list(mapzone, primary_dock, secondary_dock)

// MARK: OUTPOST
/**
 * Creates a single outpost somewhere near the center of the system.
 */
/datum/controller/subsystem/overmap/proc/spawn_outpost()
	var/turf/outpost_turf = get_unused_overmap_square()
	if(outpost_turf)
		// Create outpost - different from planet
		var/obj/structure/overmap/outpost/outpost_obj = new(outpost_turf)
		outpost_obj.name = "outpost"
	return

/datum/controller/subsystem/overmap/Recover()
	overmap_objects = SSovermap.overmap_objects
	controlled_ships = SSovermap.controlled_ships
	events = SSovermap.events
	dynamic_encounters = SSovermap.dynamic_encounters
	outposts = SSovermap.outposts
	tracked_star_systems = SSovermap.tracked_star_systems

/datum/controller/subsystem/overmap/proc/get_random_star_system()
	if(length(tracked_star_systems) >= 1) //if theres only one star system, why bother?
		return SSovermap.tracked_star_systems[1]
	else
		return SSovermap.tracked_star_systems[rand(1,length(tracked_star_systems))] //if there are more than one, grab one at random

/**
 * Gets the parent overmap object (e.g. the planet the atom is on) for a given atom.
 * * source - The object you want to get the corresponding parent overmap object for.
 */
/datum/controller/subsystem/overmap/proc/get_overmap_object_by_location(atom/source, exclude_ship = FALSE)
	return null // TODO: Implement

/**
 * Gets the interference power of nearby overmap objects.
 * Inteded to get called by radios, but i'm sure you could use this for other things.
 */
/datum/controller/subsystem/overmap/proc/get_overmap_interference(atom/source)
	return 0 // TODO: Implement

/datum/controller/subsystem/overmap/proc/load_outpost_map()
	// Load the outpost map on z-level 2
	var/datum/map_template/outpost_template = new /datum/map_template("_maps/nodalec/outpost/nanotrasen_ice.dmm")
	if(outpost_template)
		// Load at coordinates (1,1) on z-level 2
		var/turf/load_turf = locate(1, 1, 2)
		if(load_turf)
			outpost_template.load(load_turf)
			log_world("Loaded outpost map on z-level 2")

/datum/controller/subsystem/overmap/proc/spawn_player_ship(ship_config_path, mob/player)
	if(player && player.client)
		to_chat(player.client, "spawn_player_ship called with: [ship_config_path]")
	// Parse ship config
	var/list/ship_data = json_decode(file2text(ship_config_path))
	if(player && player.client)
		to_chat(player.client, "ship_data parsed: [ship_data ? "SUCCESS" : "FAILED"]")
	if(!ship_data)
		return FALSE
	
	// Create new z-level
	if(player && player.client)
		to_chat(player.client, "Creating new z-level...")
	SSmapping.add_new_zlevel("Ship Hangar", list(ZTRAIT_GRAVITY = STANDARD_GRAVITY))
	var/target_z = world.maxz
	if(player && player.client)
		to_chat(player.client, "Created z-level: [target_z]")
	
	// Load hangar first
	var/hangar_path = "_maps/nodalec/outpost/hangar/nt_ice_20x20.dmm"
	if(fexists(hangar_path))
		var/datum/map_template/hangar_template = new /datum/map_template(hangar_path)
		hangar_template.load(locate(1, 1, target_z))
	
	// Find hangar dock landmark
	var/turf/dock_turf
	var/landmarks_found = 0
	for(var/obj/effect/landmark/outpost/hangar_dock/dock_mark in world)
		landmarks_found++
		if(player && player.client)
			to_chat(player.client, "Found landmark at z=[dock_mark.z], target_z=[target_z]")
		if(dock_mark.z == target_z)
			dock_turf = get_turf(dock_mark)
			if(player && player.client)
				to_chat(player.client, "Using dock landmark at [dock_turf]")
			qdel(dock_mark)
			break
	if(player && player.client)
		to_chat(player.client, "Total landmarks found: [landmarks_found], dock_turf: [dock_turf]")
	
	// Load ship at dock position with centering offset
	var/ship_path = ship_data["map_path"]
	if(ship_path && fexists(ship_path))
		var/datum/map_template/ship_template = new /datum/map_template(ship_path)
		var/turf/load_turf
		if(dock_turf)
			// Center ship in 20x20 hangar (offset by +5,+5 from landmark)
			load_turf = locate(dock_turf.x + 5, dock_turf.y + 5, target_z)
		else
			load_turf = locate(25, 25, target_z)
		ship_template.load(load_turf)
		if(player && player.client)
			to_chat(player.client, "Ship loaded at: [load_turf] (offset from landmark)")
	
	// Teleport player to center of hangar
	if(player)
		var/spawn_turf = dock_turf || locate(25, 25, target_z)  // Keep player at hangar center
		player.forceMove(spawn_turf)
		if(player.client)
			to_chat(player.client, "Player moved to: [spawn_turf]")
	
	if(player && player.client)
		to_chat(player.client, "Spawned ship [ship_data["name"]] on z-level [target_z]")
	return TRUE

/datum/controller/subsystem/overmap/proc/create_ship_box(ship_config_path, mob/player)
	// Parse ship config
	var/list/ship_data = json_decode(file2text(ship_config_path))
	log_world("Ship data parsed: [ship_data ? "YES" : "NO"]")
	if(!ship_data)
		return FALSE
	
	// Create new z-level for ship box
	SSmapping.add_new_zlevel("Ship Box", list(ZTRAIT_GRAVITY = STANDARD_GRAVITY))
	var/target_z = world.maxz
	log_world("Created z-level: [target_z]")
	
	// Create edge borders (4 tiles thick)
	for(var/x in 1 to 60)
		for(var/y in 1 to 60)
			var/turf/T = locate(x, y, target_z)
			if(x <= 4 || x >= 57 || y <= 4 || y >= 57)
				T.ChangeTurf(/turf/closed/indestructible/edge)
			else
				T.ChangeTurf(/turf/open/space)
	log_world("Box borders created on z-level [target_z]")
	
	// Load ship in center (after borders to avoid overwriting)
	var/ship_path = ship_data["map_path"]
	log_world("Ship path: [ship_path], exists: [fexists(ship_path)]")
	if(ship_path && fexists(ship_path))
		var/datum/map_template/ship_template = new /datum/map_template(ship_path)
		var/load_result = ship_template.load(locate(25, 25, target_z))
		log_world("Ship template load result: [load_result]")
	else
		log_world("Ship not loaded - path issue")
	
	// Create overmap token
	var/turf/token_turf = get_unused_overmap_square()
	log_world("Token turf found: [token_turf ? "YES" : "NO"]")
	if(token_turf)
		var/obj/structure/overmap/ship/ship_token = new(token_turf)
		ship_token.name = ship_data["map_name"] || "Unknown Ship"
		log_world("Ship token created: [ship_token.name]")
	
	// Teleport player to ship
	if(player)
		var/turf/spawn_turf = locate(25, 25, target_z)
		log_world("Player spawn turf: [spawn_turf]")
		player.forceMove(spawn_turf)
	
	log_world("Created ship box [ship_data["name"]] on z-level [target_z] for [player]")
	return TRUE
