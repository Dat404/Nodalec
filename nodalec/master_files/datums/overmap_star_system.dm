/////////////////////////////////////////////////////////////////////
/////////////////         STAR SYSTEM DATUM         /////////////////
/////////////////////////////////////////////////////////////////////

/datum/overmap_star_system
	/// Name of the star system
	var/name
	/// Name of the star
	var/starname
	///Type of the star
	var/datum/overmap/star/startype

	///Defines which generator to use for the overmap
	var/generator_type
	///List of all overmap objects in the star system.
	var/list/overmap_objects = list()
	///List of all simulated ships in the star system.
	var/list/controlled_ships = list()
	///List of spawned outposts in the star system
	var/list/outposts = list()
	///List of all dynamic overmap datums in the star system.
	var/list/dynamic_encounters  = list()
	///List of all events in the star system.
	var/list/events = list()

	///The virtual level that contains the overmap
	var/datum/virtual_level/overmap_vlevel

	///The two-dimensional list that contains every single tile in the star system as a sublist.
	var/list/list/overmap_container

	///Map of tiles at each radius (represented by index) around the sun
	var/list/list/radius_positions
	///Width/height of the overmap "zlevel"
	var/size
	///The maximum amount of dynamic events that can spawn in this sector.
	var/max_overmap_dynamic_events
	///Do we have a outpost in this system?
	var/has_outpost = FALSE
	///The abliltiy for the system to automaticly spawn and despawn dynamic encounters
	var/encounters_refresh = FALSE
	/// Our faction of the outpost
	var/faction

	///the list of dynamic planets that can spawn in this sector
	var/list/dynamic_probabilities

	//fancy color shit! yayyyyy!

	//main colors, used for dockable terrestrials, and background
	var/primary_color = "#D8D8D8"
	var/secondary_color = "#3a3f85"

	//hazard colors, used for the overmap hazards and sun
	var/hazard_primary_color = null //this should take the color of the sun if not defined, which we want for generic sectors
	var/hazard_secondary_color = "#9D96AD"

	//structure colors, used for ships and outposts/colonies
	var/primary_structure_color = "#FFFFFF"
	var/secondary_structure_color = "#FFFFFF"

	///the tileset we use, just the icon we force tokens to use, override only if nessary
	var/tileset = 'nodalec/master_files/icons/effects/overmap.dmi'

	///This is the flag that makes it so all overmap objects use the same uniform color above. If false, tokens use their default colors
	var/override_object_colors = FALSE

	///the icon state for the overmap background. if using a bright background, use "overmap", if dark, "overmap_dark"
	var/overmap_icon_state = "overmap_dark"

	//Can players bluespace jump to this sector? Recommended to be FALSE if this is a punchcard or for some event
	var/can_jump_to = TRUE
	//can our pallete be selected randomly roundstart? set to no for subtypes or if you dont change the pallete
	var/can_be_selected_randomly = TRUE

	COOLDOWN_DECLARE(dynamic_despawn_cooldown)

/datum/overmap_star_system/New(generate_now=TRUE)
	if(generate_now)
		setup_system()

/datum/overmap_star_system/proc/setup_system()
	if(!starname)
		starname = gen_star_name() //we reuse this for the name of the star if name isnt defined, like a uncharted sector or something
	if(!name)
		name = starname //we then give it here
	overmap_objects = list()
	controlled_ships = list()
	outposts = list()
	events = list()

	if(isnull(dynamic_probabilities))
		dynamic_probabilities = list()

	if(!generator_type)
		generator_type = CONFIG_GET(string/overmap_generator_type)
	if(!size)
		size = CONFIG_GET(number/overmap_size)
	if(!max_overmap_dynamic_events)
		max_overmap_dynamic_events = CONFIG_GET(number/max_overmap_dynamic_events)

	overmap_container = new/list(size, size, 0)

	var/encounter_name = name
	var/datum/map_zone/mapzone = SSmapping.create_map_zone(encounter_name)
	overmap_vlevel = SSmapping.create_virtual_level(encounter_name, list(), mapzone, size + MAP_EDGE_PAD * 2, size + MAP_EDGE_PAD * 2)
	// overmap_vlevel.current_system = src // TODO: Add this field if needed
	overmap_vlevel.reserve_margin(MAP_EDGE_PAD)
	overmap_vlevel.fill_in(/turf/open/overmap, /area/overmap)
	overmap_vlevel.selfloop()
	var/area/our_area = get_area(OVERMAP_TOKEN_TURF(1, 1, src))

	// our_area.rename_area ("[our_area.name] ([name])") // TODO: Implement if needed
	//before you ask, no, for some reason it doesnt add itself automatically
	if(!(our_area in GLOB.sortedAreas))
		GLOB.sortedAreas.Add(our_area)
		sortTim(GLOB.sortedAreas, /proc/cmp_name_asc)

	if (!generator_type) //TODO: maybe datumize these?
		generator_type = OVERMAP_GENERATOR_RANDOM

	if ((generator_type == OVERMAP_GENERATOR_SOLAR) || (generator_type == OVERMAP_GENERATOR_RANDOM))
		var/datum/overmap/star/center = new /datum/overmap/star(list("x" = round(size / 2 + 1), "y" = round(size / 2 + 1)), src)
		if(starname)
			center.name = starname
		radius_positions = list()
		for(var/x in 1 to size)
			for(var/y in 1 to size)
				radius_positions["[round(sqrt((x - center.x) ** 2 + (y - center.y) ** 2)) + 1]"] += list(list("x" = x, "y" = y))

	create_map()

/datum/overmap_star_system/Destroy(force, ...)
	//if we haven't even generated a map yet, don't freak out about it
	if(!overmap_container)
		return ..()
	if(!force)
		stack_trace("Something has attempted to delete a star system. THIS SHOULD NEVER HAPPEN. STACK TRACING TO SEE WHY THIS IS HAPPENING.")
		message_admins("<span class='danger'>Something has attempted to delete a star system. THIS SHOULD NEVER HAPPEN. STACK TRACING TO SEE WHY THIS IS HAPPENING. CHECK RUNTIMES.</span>")
		return QDEL_HINT_LETMELIVE
	stack_trace("Something has attempted to delete a star system but it was a force delete, so we are assuming it was inentional. This should still not happen reguardless, but cleaning up the system.")
	message_admins("<span class='danger'>Something has attempted to delete a star system but it was a force delete, so we are assuming it was inentional. This should still not happen reguardless, but cleaning up the system.</span>")
	SSovermap.tracked_star_systems -= src
	for(var/datum/thing_to_del as anything in overmap_objects)
		qdel(thing_to_del)
	return ..()

/datum/overmap_star_system/proc/gen_star_name()
	return "[pick(GLOB.star_names)] [pick(GLOB.greek_letters)]"

/**
 * The proc that creates all the objects on the overmap, split into seperate procs for redundancy.
 */
/datum/overmap_star_system/proc/create_map()
	switch(generator_type)
		if(OVERMAP_GENERATOR_SOLAR)
			spawn_events_in_orbits()
		if(OVERMAP_GENERATOR_RANDOM)
			spawn_events()

	spawn_ruin_levels()

	if(has_outpost)
		spawn_outpost()

/**
 * VERY Simple random generation for overmap events, spawns the event in a random turf and sometimes spreads it out similar to ores
 */
/datum/overmap_star_system/proc/spawn_events()
	// TODO: Implement event spawning
	return

/datum/overmap_star_system/proc/spawn_events_in_orbits()
	// TODO: Implement orbital event spawning
	return

/**
 * Creates an overmap object for each ruin level, making them accessible.
 */
/datum/overmap_star_system/proc/spawn_ruin_levels()
	for(var/i in 1 to max_overmap_dynamic_events)
		spawn_ruin_level()

/datum/overmap_star_system/proc/spawn_ruin_level()
	// TODO: Implement ruin level spawning
	return

/**
 * See [/datum/controller/subsystem/overmap/proc/spawn_events], spawns "veins" (like ores) of events
 */
/datum/overmap_star_system/proc/spawn_event_cluster(type, list/location, chance)
	// TODO: Implement event clustering
	// Suppress unused variable warnings
	. = type || location || chance
	return

/**
 * Creates a single outpost somewhere near the center of the system.
 */
/datum/overmap_star_system/proc/spawn_outpost()
	var/list/location = get_unused_overmap_square_in_radius(rand(4, round(size/5)))

	var/datum/overmap/outpost/found_type
	if(fexists(OUTPOST_OVERRIDE_FILEPATH))
		var/file_text = trim_right(file2text(OUTPOST_OVERRIDE_FILEPATH)) // trim_right because there's often a trailing newline
		var/datum/overmap/outpost/potential_type = text2path(file_text)
		if(!potential_type || !ispath(potential_type, /datum/overmap/outpost))
			stack_trace("SSovermap found an outpost override file at [OUTPOST_OVERRIDE_FILEPATH], but was unable to find the outpost type [potential_type]!")
		else
			found_type = potential_type
		fdel(OUTPOST_OVERRIDE_FILEPATH) // don't want it to affect 2 rounds in a row.

	if(!found_type)
		var/list/possible_types = subtypesof(/datum/overmap/outpost)
		for(var/datum/overmap/outpost/outpost_type as anything in possible_types)
			if(!initial(outpost_type.main_template))
				possible_types -= outpost_type
		found_type = pick(possible_types)

	// var/datum/overmap/outpost/our_outpost = new found_type(location, src)
	// TODO: Implement outpost creation
	return

/**
 * Returns a random, usually empty turf in the overmap
 * * thing_to_not_have - The thing you don't want to be in the found tile, for example, an overmap event [/datum/overmap/event].
 * * tries - How many attempts it will try before giving up finding an unused tile.
 */
/datum/overmap_star_system/proc/get_unused_overmap_square(thing_to_not_have = /datum/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	for(var/i in 1 to tries)
		. = list("x" = rand(1, size), "y" = rand(1, size))
		if(locate(thing_to_not_have) in overmap_container[.["x"]][.["y"]])
			continue
		return

	if(!force)
		. = null

/**
 * Returns a random turf in a radius from the star, or a random empty turf if OVERMAP_GENERATOR_RANDOM is the active generator.
 * * thing_to_not_have - The thing you don't want to be in the found tile, for example, an overmap event [/datum/overmap/event].
 * * tries - How many attempts it will try before giving up finding an unused tile..
 * * radius - The distance from the star to search for an empty tile.
 */
/datum/overmap_star_system/proc/get_unused_overmap_square_in_radius(radius, thing_to_not_have = /datum/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	if(!radius)
		radius = "[rand(3, length(radius_positions) / 2)]"
	if(isnum(radius))
		radius = "[radius]"

	for(var/i in 1 to tries)
		. = pick(radius_positions[radius])
		if(locate(thing_to_not_have) in overmap_container[.["x"]][.["y"]])
			continue
		return // returns . for those who don't know

	if(!force)
		. = null

/**
 * This is tangentily related to dynmaic missions, its doing the same despawn thing you added for overmap events. Its meant to cycle out planets very slowly.
 */
/datum/overmap_star_system/proc/handle_dynamic_encounters()
	// TODO: Implement dynamic encounter handling
	return

//default nodalec overmap
/datum/overmap_star_system/nodalec
	has_outpost = TRUE
	can_be_selected_randomly = FALSE
	encounters_refresh = TRUE