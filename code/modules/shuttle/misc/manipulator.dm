/obj/machinery/shuttle_manipulator
	name = "shuttle manipulator"
	desc = "I shall be telling this with a sigh\n\
		Somewhere ages and ages hence:\n\
		Two roads diverged in a wood, and I,\n\
		I took the one less traveled by,\n\
		And that has made all the difference."

	icon = 'icons/obj/machines/shuttle_manipulator.dmi'
	icon_state = "holograph_on"

	density = TRUE
	interaction_flags_machine = INTERACT_MACHINE_ALLOW_SILICON | INTERACT_MACHINE_REQUIRES_SIGHT

/obj/machinery/shuttle_manipulator/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	
	// Simple direct spawn
	var/config_path = "_maps/nodalec/configs/independent_alone.json"
	if(SSovermap.spawn_player_ship(config_path, user))
		to_chat(user, "Ship spawned successfully!")
	else
		to_chat(user, "Failed to spawn ship.")
