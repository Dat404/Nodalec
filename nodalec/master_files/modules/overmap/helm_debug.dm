// Debug commands for helm console

/client/proc/connect_helm_to_ship()
	set name = "Connect Helm to Ship"
	set category = "Admin"
	
	if(!check_rights(R_ADMIN))
		return
		
	var/obj/machinery/computer/helm/console = locate() in view(7, mob)
	if(!console)
		to_chat(src, "No helm console nearby!")
		return
		
	var/obj/structure/overmap/ship/ship = locate() in SSovermap.controlled_ships
	if(!ship)
		to_chat(src, "No ships in system!")
		return
		
	console.connected_ship = ship
	to_chat(src, "Connected helm console to [ship.name]")

/client/proc/list_ships()
	set name = "List Ships"
	set category = "Admin"
	
	if(!check_rights(R_ADMIN))
		return
		
	to_chat(src, "Ships in system:")
	for(var/obj/structure/overmap/ship/ship in SSovermap.controlled_ships)
		to_chat(src, "- [ship.name] at [ship.x],[ship.y] (shuttle: [ship.shuttle ? "YES" : "NO"])")