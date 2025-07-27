/**
 * # Overmap Star
 *
 * Stars are the central objects of star systems.
 */
/datum/overmap/star
	name = "star"
	desc = "A burning ball of gas that provides light and heat to the system."
	icon_state = "star"
	color = "#FFFF00"
	/// Spectral type of the star
	var/spectral_type = 4 // STAR_G equivalent
	/// Whether the star uses a custom color
	var/custom_color = TRUE
	/// Color variation for the star
	var/color_vary = 20

/datum/overmap/star/proc/get_rand_spectral_color(spectral_type, color_vary)
	return "#FFFF00" // Simple yellow for now

/**
 * # Planet Type Datum
 *
 * Defines the properties of different planet types.
 */
/datum/planet_type
	/// Name of the planet type
	var/name = "Generic Planet"
	/// Weight for random selection
	var/weight = 10
	/// The planet identifier
	var/planet = "lava"
	/// Icon state for the planet
	var/icon_state = "planet"
	/// Color of the planet
	var/color = "#8B4513"
	/// Description of the planet
	var/desc = "A generic planet."

/datum/planet_type/lava
	name = "Lava Planet"
	planet = "lava"
	icon_state = "planet_lava"
	color = "#FF4500"
	desc = "A molten world covered in lava flows and volcanic activity."