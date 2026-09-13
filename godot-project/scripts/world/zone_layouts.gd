# ZoneLayouts — the geometry for zones two and three, and their interiors.
#
# Kept in its own file rather than bolted onto ZoneBuilder for one reason: the
# desktop's Blender sessions edit ZoneBuilder (the KIT table, the house builder)
# and this file never needs to be touched by them. Two people can work without
# stepping on each other.
#
# Everything here returns the same {pos, size, color, solid, rot, kit} piece
# dictionaries ZoneBuilder._build_piece() understands, and calls back into
# ZoneBuilder for the shared helpers — house(), tree(), banner() and the colour
# constants — so a kit piece landing on disk upgrades these zones too.
#
# World layout, since portals move you inside one continuous world rather than
# loading a level:
#
#   Thornhollow Vale   x ~ 0        y 0        (barrow at y -500)
#   Sablemarch         x ~ 600      y 0        (redoubt at y -1000)
#   Kingsmourn         x ~ 1200     y 0        (crypt -1200, hall -1500,
#                                               throne -2000)
#
# The gaps are deliberate and generous: a zone you can see from another zone
# reads as a mistake, and fall-limits per region depend on them not overlapping.
class_name ZoneLayouts
extends RefCounted

## Where each region sits in world space. Scenes and portals both read these, so
## moving a zone is a one-line change instead of a hunt through .tscn files.
const SABLEMARCH_ORIGIN := Vector3(600, 0, 0)
const REDOUBT_ORIGIN := Vector3(600, -1000, -600)
const KINGSMOURN_ORIGIN := Vector3(1200, 0, 0)
const CRYPT_ORIGIN := Vector3(1200, -1200, -600)
const HALL_ORIGIN := Vector3(1200, -1500, -600)
const THRONE_ORIGIN := Vector3(1200, -2000, -600)

# Colours the marches and the capital need that the vale never did.
const MUD := Color(0.42, 0.38, 0.30)
const MUD_DARK := Color(0.33, 0.30, 0.24)
const FLOOD := Color(0.31, 0.42, 0.46)
const MARBLE := Color(0.90, 0.88, 0.82)
const MARBLE_DARK := Color(0.74, 0.71, 0.66)
const STAG := Color(0.24, 0.42, 0.28)
const SUNBURST := Color(0.22, 0.32, 0.60)
const PARCHMENT := Color(0.78, 0.72, 0.55)
const IRON := Color(0.30, 0.31, 0.34)


# --- Small shared shapes ----------------------------------------------------


## A box, with the defaults every layout wants.
static func slab(at: Vector3, size: Vector3, color: Color, solid: bool = true) -> Dictionary:
	return {"pos": at, "size": size, "color": color, "solid": solid}


## Four walls and a ceiling around a room. Every interior is made of these, and
## writing them out by hand five times is how a wall ends up missing.
static func room(centre: Vector3, width: float, depth: float, height: float, color: Color) -> Array:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var mid := height * 0.5
	return [
		slab(centre + Vector3(0, -0.5, 0), Vector3(width, 1, depth), color),
		slab(centre + Vector3(0, height + 0.5, 0), Vector3(width, 1, depth), color),
		slab(centre + Vector3(-half_w, mid, 0), Vector3(1.5, height, depth), color),
		slab(centre + Vector3(half_w, mid, 0), Vector3(1.5, height, depth), color),
		slab(centre + Vector3(0, mid, -half_d), Vector3(width, height, 1.5), color),
		slab(centre + Vector3(0, mid, half_d), Vector3(width, height, 1.5), color)
	]


## Same as room(), but open at one end so a corridor can join it. `open` is
## "north" or "south".
static func hall(centre: Vector3, width: float, depth: float, height: float, color: Color, open: String) -> Array:
	var pieces := room(centre, width, depth, height, color)
	# room() builds south wall last, north wall second-to-last.
	if open == "south":
		pieces.remove_at(pieces.size() - 1)
	elif open == "north":
		pieces.remove_at(pieces.size() - 2)
	elif open == "both":
		pieces.remove_at(pieces.size() - 1)
		pieces.remove_at(pieces.size() - 1)
	return pieces


## A corridor: floor, two walls, ceiling. Runs along Z.
static func corridor(centre: Vector3, width: float, length: float, height: float, color: Color) -> Array:
	var half_w := width * 0.5
	return [
		slab(centre + Vector3(0, -0.5, 0), Vector3(width, 1, length), color),
		slab(centre + Vector3(0, height + 0.5, 0), Vector3(width, 1, length), color),
		slab(centre + Vector3(-half_w, height * 0.5, 0), Vector3(1.5, height, length), color),
		slab(centre + Vector3(half_w, height * 0.5, 0), Vector3(1.5, height, length), color)
	]


## Boundary walls so nobody walks off the edge of a zone.
static func bounds(centre: Vector3, width: float, depth: float, color: Color) -> Array:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	return [
		slab(centre + Vector3(0, 6, half_d), Vector3(width + 2, 12, 2), color),
		slab(centre + Vector3(0, 6, -half_d), Vector3(width + 2, 12, 2), color),
		slab(centre + Vector3(-half_w, 6, 0), Vector3(2, 12, depth + 2), color),
		slab(centre + Vector3(half_w, 6, 0), Vector3(2, 12, depth + 2), color)
	]


## A pillar, because every interior wants a row of them.
static func pillars(centre: Vector3, xs: Array, zs: Array, height: float, thickness: float, color: Color) -> Array:
	var pieces: Array = []
	for x in xs:
		for z in zs:
			pieces.append(slab(centre + Vector3(float(x), height * 0.5, float(z)), Vector3(thickness, height, thickness), color))
	return pieces


## A field tent — the marches are an army camp, not a town.
static func tent(at: Vector3, width: float = 5.0) -> Array:
	return [
		slab(at + Vector3(0, 1.4, 0), Vector3(width, 2.8, width * 0.8), Color(0.62, 0.58, 0.46)),
		slab(at + Vector3(0, 3.2, 0), Vector3(width * 0.7, 1.2, width * 0.6), Color(0.52, 0.48, 0.38), false)
	]


## A market stall, for the capital's market ward.
static func stall(at: Vector3, cloth: Color) -> Array:
	return [
		slab(at + Vector3(0, 0.9, 0), Vector3(3.0, 1.8, 2.0), ZoneBuilder.TIMBER),
		slab(at + Vector3(0, 2.2, 0), Vector3(3.6, 0.3, 2.6), cloth, false)
	]


# --- Zone 2: Sablemarch ----------------------------------------------------


## Sablemarch: a year-old battlefield between two armies, flooded and full of
## the dead that the water keeps giving back. Levels 8-14.
##
## Shape: the road arrives from the vale in the south, runs through a field camp
## that both houses tolerate because the surgeon is in it, out across the
## contested middle with a picket line on each flank, over the ferry crossing,
## and up to the Drowned Redoubt in the north.
static func sablemarch() -> Array:
	var o := SABLEMARCH_ORIGIN
	var pieces: Array = []

	# Ground: churned mud rather than the vale's green. Same trick as the vale,
	# a darker plate further out so the eye has somewhere to travel.
	pieces.append(slab(o + Vector3(0, -0.5, 0), Vector3(280, 1.0, 360), MUD))
	pieces.append(slab(o + Vector3(0, -0.44, -60), Vector3(240, 1.0, 200), MUD_DARK, false))

	# Standing flood water. The zone's whole idea in one colour.
	for pool in [
		{"at": Vector3(-40, 0, -20), "size": Vector3(70, 0.4, 46)},
		{"at": Vector3(52, 0, -44), "size": Vector3(60, 0.4, 40)},
		{"at": Vector3(-8, 0, -96), "size": Vector3(96, 0.4, 34)},
		{"at": Vector3(36, 0, 30), "size": Vector3(38, 0.4, 26)}
	]:
		pieces.append(slab(o + pool["at"] + Vector3(0, 0.05, 0), pool["size"], FLOOD, false))

	# The road in from Thornhollow, and on to the redoubt.
	pieces.append(slab(o + Vector3(0, 0.08, 120), Vector3(8, 0.2, 120), ZoneBuilder.ROAD, false))
	pieces.append(slab(o + Vector3(0, 0.08, -40), Vector3(7, 0.2, 200), ZoneBuilder.ROAD, false))

	# --- The field camp, south end ---
	pieces.append(slab(o + Vector3(0, 0.1, 112), Vector3(44, 0.3, 38), MUD_DARK))
	# Wrenn's surgery and Colm's command tent are the only real buildings.
	pieces.append_array(ZoneBuilder.house(o + Vector3(-16, 0, 118), 8, 6, 1))
	pieces.append_array(ZoneBuilder.house(o + Vector3(16, 0, 118), 8, 6, 1))
	for spot in [Vector3(-8, 0, 104), Vector3(0, 0, 100), Vector3(9, 0, 104), Vector3(-18, 0, 102)]:
		pieces.append_array(tent(o + spot))
	# Neutral ground, so neither banner flies over it.
	pieces.append_array(ZoneBuilder.banner(o + Vector3(-22, 0, 112), Color(0.72, 0.70, 0.64)))
	pieces.append_array(ZoneBuilder.banner(o + Vector3(22, 0, 112), Color(0.72, 0.70, 0.64)))

	# --- Picket lines: Stag west, Sunburst east ---
	for i in range(6):
		var z := 60.0 - float(i) * 22.0
		pieces.append(slab(o + Vector3(-74, 0.8, z), Vector3(14, 1.6, 3), MUD_DARK))
		pieces.append(slab(o + Vector3(74, 0.8, z), Vector3(14, 1.6, 3), MUD_DARK))
	for spot in [Vector3(-80, 0, 44), Vector3(-80, 0, 0), Vector3(-80, 0, -44)]:
		pieces.append_array(tent(o + spot, 4.5))
		pieces.append_array(ZoneBuilder.banner(o + spot + Vector3(6, 0, 0), STAG))
	for spot in [Vector3(80, 0, 44), Vector3(80, 0, 0), Vector3(80, 0, -44)]:
		pieces.append_array(tent(o + spot, 4.5))
		pieces.append_array(ZoneBuilder.banner(o + spot + Vector3(-6, 0, 0), SUNBURST))

	# --- The contested middle: trenches, and what is left in them ---
	for i in range(5):
		var z := 40.0 - float(i) * 30.0
		pieces.append(slab(o + Vector3(-30, 0.6, z), Vector3(46, 1.2, 2.5), MUD_DARK))
		pieces.append(slab(o + Vector3(30, 0.6, z + 14), Vector3(46, 1.2, 2.5), MUD_DARK))
	# Dead trees. Nothing in this zone is alive that does not have to be.
	for spot in [Vector3(-52, 0, 76), Vector3(58, 0, 84), Vector3(-64, 0, -70), Vector3(66, 0, -86), Vector3(-20, 0, -128)]:
		pieces.append_array(ZoneBuilder.tree(o + spot, 0.8))

	# --- The ferry crossing ---
	pieces.append(slab(o + Vector3(0, 0.1, -96), Vector3(120, 0.5, 30), FLOOD, false))
	# The causeway over it, which is the only way north on foot.
	pieces.append(slab(o + Vector3(0, 0.9, -96), Vector3(10, 1.0, 34), ZoneBuilder.TIMBER))
	pieces.append_array(ZoneBuilder.house(o + Vector3(-16, 0, -80), 6, 6, 1))
	for post_z in [-84, -96, -108]:
		pieces.append(slab(o + Vector3(-5.5, 1.8, float(post_z)), Vector3(0.4, 2.6, 0.4), ZoneBuilder.TIMBER))
		pieces.append(slab(o + Vector3(5.5, 1.8, float(post_z)), Vector3(0.4, 2.6, 0.4), ZoneBuilder.TIMBER))

	# --- The redoubt approach, north end ---
	pieces.append(slab(o + Vector3(0, 0.1, -150), Vector3(60, 0.4, 40), MUD_DARK))
	# The fort itself, seen from outside: a squat wall with a gate in it.
	pieces.append(slab(o + Vector3(-22, 5, -168), Vector3(34, 10, 4), ZoneBuilder.STONE_DARK))
	pieces.append(slab(o + Vector3(22, 5, -168), Vector3(34, 10, 4), ZoneBuilder.STONE_DARK))
	pieces.append(slab(o + Vector3(0, 8.5, -168), Vector3(12, 3, 4), ZoneBuilder.STONE_DARK))
	for tower_x in [-39, 39]:
		pieces.append(slab(o + Vector3(float(tower_x), 7, -168), Vector3(9, 14, 9), ZoneBuilder.STONE_DARK))

	pieces.append_array(bounds(o, 280, 360, MUD_DARK))
	return pieces


## Inside the Drowned Redoubt. A siege fort standing in water, held by nobody:
## both houses threw men at it for a year and the water gave them all back.
static func redoubt_interior() -> Array:
	var o := REDOUBT_ORIGIN
	var pieces: Array = []

	# Rock shell, so no daylight shows between the rooms.
	pieces.append(slab(o + Vector3(0, -2, -60), Vector3(120, 2, 230), IRON))
	pieces.append(slab(o + Vector3(0, 20, -60), Vector3(120, 2, 230), IRON))
	pieces.append(slab(o + Vector3(-59, 9, -60), Vector3(2, 24, 230), IRON))
	pieces.append(slab(o + Vector3(59, 9, -60), Vector3(2, 24, 230), IRON))
	pieces.append(slab(o + Vector3(0, 9, 54), Vector3(120, 24, 2), IRON))
	pieces.append(slab(o + Vector3(0, 9, -175), Vector3(120, 24, 2), IRON))

	# Entry causeway: a raised walk with water either side of it.
	pieces.append_array(corridor(o + Vector3(0, 0, 18), 16, 40, 10, ZoneBuilder.STONE_DARK))
	pieces.append(slab(o + Vector3(0, 0.2, 18), Vector3(13, 0.4, 40), FLOOD, false))

	# The courtyard, where the two captains are still fighting each other.
	pieces.append_array(hall(o + Vector3(0, 0, -30), 52, 52, 14, ZoneBuilder.STONE_DARK, "both"))
	pieces.append(slab(o + Vector3(0, 0.2, -30), Vector3(48, 0.4, 48), FLOOD, false))
	pieces.append_array(pillars(o + Vector3(0, 0, -30), [-16, 16], [-14, 14], 14, 3.0, ZoneBuilder.STONE))
	# Their banners, still up, on opposite walls.
	pieces.append(slab(o + Vector3(-24, 8, -44), Vector3(0.5, 7, 4), STAG, false))
	pieces.append(slab(o + Vector3(24, 8, -44), Vector3(0.5, 7, 4), SUNBURST, false))

	# The stair down to the cistern.
	pieces.append_array(corridor(o + Vector3(0, 0, -74), 14, 32, 10, ZoneBuilder.STONE_DARK))

	# The cistern: deeper water, and the pile the water made of everyone.
	pieces.append_array(hall(o + Vector3(0, 0, -120), 60, 56, 16, IRON, "north"))
	pieces.append(slab(o + Vector3(0, 0.3, -120), Vector3(56, 0.6, 52), FLOOD, false))
	pieces.append_array(pillars(o + Vector3(0, 0, -120), [-20, 20], [-18, 18], 16, 3.4, ZoneBuilder.STONE_DARK))
	# The heap itself, as scenery, under where the boss stands.
	pieces.append(slab(o + Vector3(0, 1.2, -132), Vector3(16, 2.4, 10), MUD_DARK))

	return pieces


# --- Zone 3: Kingsmourn ----------------------------------------------------


## Kingsmourn: the capital, sunlit and prosperous and about a week from tearing
## itself apart. Levels 14-20.
##
## Shape: Kingsgate in the south, one avenue running the length of the city,
## market ward, guild quarter either side, the Records Quarter west, and the
## palace ward walled off at the north end.
static func kingsmourn() -> Array:
	var o := KINGSMOURN_ORIGIN
	var pieces: Array = []

	# Ground: paved, not grass. A city floor.
	pieces.append(slab(o + Vector3(0, -0.5, 0), Vector3(300, 1.0, 420), ZoneBuilder.COBBLE))
	pieces.append(slab(o + Vector3(0, -0.44, 190), Vector3(300, 1.0, 60), ZoneBuilder.GRASS_DARK, false))

	# The avenue, gate to palace.
	pieces.append(slab(o + Vector3(0, 0.08, 0), Vector3(16, 0.2, 380), ZoneBuilder.STONE_DARK, false))

	# --- Kingsgate, south ---
	pieces.append(slab(o + Vector3(-30, 8, 178), Vector3(46, 16, 5), ZoneBuilder.STONE))
	pieces.append(slab(o + Vector3(30, 8, 178), Vector3(46, 16, 5), ZoneBuilder.STONE))
	pieces.append(slab(o + Vector3(0, 13, 178), Vector3(16, 6, 5), ZoneBuilder.STONE))
	for tower_x in [-55, 55]:
		pieces.append(slab(o + Vector3(float(tower_x), 11, 178), Vector3(12, 22, 12), ZoneBuilder.STONE))
		pieces.append(slab(o + Vector3(float(tower_x), 23, 178), Vector3(13, 3, 13), ZoneBuilder.SLATE))
	pieces.append_array(ZoneBuilder.banner(o + Vector3(-12, 0, 168), ZoneBuilder.GOLD))
	pieces.append_array(ZoneBuilder.banner(o + Vector3(12, 0, 168), ZoneBuilder.GOLD))

	# --- Market ward ---
	pieces.append(slab(o + Vector3(0, 0.1, 110), Vector3(70, 0.3, 60), ZoneBuilder.COBBLE))
	# Fountain, matching the vale's so the two read as one kingdom.
	pieces.append(slab(o + Vector3(0, 0.5, 110), Vector3(9, 0.8, 9), ZoneBuilder.STONE_DARK))
	pieces.append(slab(o + Vector3(0, 0.95, 110), Vector3(7.6, 0.3, 7.6), ZoneBuilder.WATER, false))
	pieces.append(slab(o + Vector3(0, 2.2, 110), Vector3(1.4, 3.4, 1.4), ZoneBuilder.STONE))
	for i in range(4):
		var z := 92.0 + float(i) * 12.0
		pieces.append_array(stall(o + Vector3(-22, 0, z), Color(0.66, 0.28, 0.26)))
		pieces.append_array(stall(o + Vector3(22, 0, z), Color(0.30, 0.44, 0.62)))
	for spot in [Vector3(-30, 0, 84), Vector3(30, 0, 84), Vector3(-30, 0, 136), Vector3(30, 0, 136)]:
		pieces.append_array(ZoneBuilder.tree(o + spot, 0.9))
	# Shops around the market edge.
	for x in [-44, 44]:
		for z in [88, 106, 124]:
			pieces.append_array(ZoneBuilder.house(o + Vector3(float(x), 0, float(z)), 12, 10, 2))

	# --- Guild quarter: two rows of tall houses along the avenue ---
	for z in [40, 20, 0, -20]:
		pieces.append_array(ZoneBuilder.house(o + Vector3(-26, 0, float(z)), 14, 12, 3))
		pieces.append_array(ZoneBuilder.house(o + Vector3(26, 0, float(z)), 14, 12, 3))
	for z in [44, 8, -28]:
		pieces.append_array(ZoneBuilder.house(o + Vector3(-54, 0, float(z)), 14, 12, 2))
		pieces.append_array(ZoneBuilder.house(o + Vector3(54, 0, float(z)), 14, 12, 2))
	# Both houses' colours, hung in a street that belongs to neither.
	for z in [36, 4, -32]:
		pieces.append_array(ZoneBuilder.banner(o + Vector3(-11, 0, float(z)), STAG))
		pieces.append_array(ZoneBuilder.banner(o + Vector3(11, 0, float(z)), SUNBURST))

	# --- Records Quarter, west ---
	pieces.append(slab(o + Vector3(-74, 0.1, -66), Vector3(74, 0.3, 70), MARBLE_DARK))
	# The Hall of Records itself: a marble front with a stair and columns, the
	# one building in the city that is not made of the town kit.
	pieces.append(slab(o + Vector3(-74, 0.6, -44), Vector3(46, 1.2, 10), MARBLE))
	pieces.append(slab(o + Vector3(-74, 9, -76), Vector3(50, 18, 34), MARBLE))
	pieces.append(slab(o + Vector3(-74, 19, -76), Vector3(54, 3, 38), MARBLE_DARK))
	for col_x in [-92, -83, -74, -65, -56]:
		pieces.append(slab(o + Vector3(float(col_x), 7, -57), Vector3(2.6, 14, 2.6), MARBLE))
	pieces.append(slab(o + Vector3(-74, 15.5, -57), Vector3(50, 3, 4), MARBLE_DARK))
	# The doors, shut, which is the whole point of the quest that sends you here.
	pieces.append(slab(o + Vector3(-74, 4, -59.5), Vector3(9, 8, 1), ZoneBuilder.TIMBER))

	# --- Palace ward, north, walled ---
	pieces.append(slab(o + Vector3(0, 6, -110), Vector3(120, 12, 4), ZoneBuilder.STONE))
	pieces.append(slab(o + Vector3(0, 9.5, -110), Vector3(18, 5, 4), ZoneBuilder.STONE))
	pieces.append(slab(o + Vector3(0, 0.1, -150), Vector3(120, 0.3, 76), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 12, -178), Vector3(90, 24, 30), ZoneBuilder.STONE))
	pieces.append(slab(o + Vector3(0, 25, -178), Vector3(94, 4, 34), ZoneBuilder.SLATE))
	for wing_x in [-52, 52]:
		pieces.append(slab(o + Vector3(float(wing_x), 15, -172), Vector3(18, 30, 18), ZoneBuilder.STONE))
		pieces.append(slab(o + Vector3(float(wing_x), 31, -172), Vector3(20, 4, 20), ZoneBuilder.SLATE))
	for spot in [Vector3(-30, 0, -140), Vector3(30, 0, -140)]:
		pieces.append_array(ZoneBuilder.banner(o + spot, ZoneBuilder.GOLD))
	# The crypt stair, a dark mouth in the palace ward floor.
	pieces.append(slab(o + Vector3(-34, 0.3, -124), Vector3(12, 0.6, 12), ZoneBuilder.STONE_DARK))
	pieces.append(slab(o + Vector3(-34, 2.5, -130), Vector3(12, 5, 2), ZoneBuilder.STONE_DARK))

	pieces.append_array(bounds(o, 300, 420, ZoneBuilder.STONE_DARK))
	return pieces


## The royal crypt, under the palace ward. Where the kings before this one are,
## and where something has been getting them up again.
static func royal_crypt_interior() -> Array:
	var o := CRYPT_ORIGIN
	var pieces: Array = []

	pieces.append(slab(o + Vector3(0, -2, -50), Vector3(90, 2, 180), ZoneBuilder.BARROW))
	pieces.append(slab(o + Vector3(0, 16, -50), Vector3(90, 2, 180), ZoneBuilder.BARROW))
	pieces.append(slab(o + Vector3(-44, 7, -50), Vector3(2, 20, 180), ZoneBuilder.BARROW))
	pieces.append(slab(o + Vector3(44, 7, -50), Vector3(2, 20, 180), ZoneBuilder.BARROW))
	pieces.append(slab(o + Vector3(0, 7, 40), Vector3(90, 20, 2), ZoneBuilder.BARROW))
	pieces.append(slab(o + Vector3(0, 7, -140), Vector3(90, 20, 2), ZoneBuilder.BARROW))

	# The stair down, then a long vaulted gallery of niches.
	pieces.append_array(corridor(o + Vector3(0, 0, 14), 12, 34, 9, ZoneBuilder.STONE_DARK))
	pieces.append_array(hall(o + Vector3(0, 0, -34), 40, 66, 12, ZoneBuilder.STONE_DARK, "north"))
	pieces.append_array(pillars(o + Vector3(0, 0, -34), [-13, 13], [-22, 0, 22], 12, 2.6, ZoneBuilder.STONE))
	# Niches along both walls, each with a king in it.
	for i in range(7):
		var z := -6.0 - float(i) * 9.0
		pieces.append(slab(o + Vector3(-17, 1.2, z), Vector3(4, 2.4, 6), ZoneBuilder.STONE))
		pieces.append(slab(o + Vector3(17, 1.2, z), Vector3(4, 2.4, 6), ZoneBuilder.STONE))

	# The binders' end of it: a working chamber that should not exist.
	pieces.append_array(corridor(o + Vector3(0, 0, -76), 12, 22, 9, ZoneBuilder.STONE_DARK))
	pieces.append_array(hall(o + Vector3(0, 0, -106), 44, 40, 12, ZoneBuilder.STONE_DARK, "south"))
	pieces.append(slab(o + Vector3(0, 0.6, -110), Vector3(14, 1.2, 10), Color(0.40, 0.22, 0.45)))
	for spot in [Vector3(-14, 0, -96), Vector3(14, 0, -96), Vector3(-14, 0, -120), Vector3(14, 0, -120)]:
		pieces.append(slab(o + spot + Vector3(0, 1.4, 0), Vector3(1.6, 2.8, 1.6), Color(0.34, 0.18, 0.38)))

	return pieces


## The Hall of Records — dungeon three. A reading hall, a scriptorium where
## Master Kell is, a vault stair, and the vault with the Bound Ledger and its
## four braziers.
static func hall_of_records_interior() -> Array:
	var o := HALL_ORIGIN
	var pieces: Array = []

	pieces.append(slab(o + Vector3(0, -2, -60), Vector3(110, 2, 220), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 22, -60), Vector3(110, 2, 220), MARBLE_DARK))
	pieces.append(slab(o + Vector3(-54, 10, -60), Vector3(2, 26, 220), MARBLE_DARK))
	pieces.append(slab(o + Vector3(54, 10, -60), Vector3(2, 26, 220), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 10, 50), Vector3(110, 26, 2), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 10, -170), Vector3(110, 26, 2), MARBLE_DARK))

	# --- The reading hall: long, and lined with shelves ---
	pieces.append_array(hall(o + Vector3(0, 0, -6), 46, 86, 16, MARBLE, "north"))
	pieces.append_array(pillars(o + Vector3(0, 0, -6), [-15, 15], [-28, -8, 12, 32], 16, 2.8, MARBLE))
	# Shelves. The trash fight happens between these.
	for i in range(8):
		var z := 28.0 - float(i) * 8.0
		pieces.append(slab(o + Vector3(-20, 2.2, z), Vector3(4, 4.4, 5), PARCHMENT))
		pieces.append(slab(o + Vector3(20, 2.2, z), Vector3(4, 4.4, 5), PARCHMENT))
	# Lecterns down the middle.
	for z in [16, 0, -16]:
		pieces.append(slab(o + Vector3(0, 0.7, float(z)), Vector3(1.6, 1.4, 1.2), ZoneBuilder.TIMBER))

	# --- The scriptorium: Master Kell ---
	pieces.append_array(corridor(o + Vector3(0, 0, -56), 14, 26, 12, MARBLE))
	pieces.append_array(hall(o + Vector3(0, 0, -90), 50, 44, 16, MARBLE, "south"))
	pieces.append_array(pillars(o + Vector3(0, 0, -90), [-17, 17], [-14, 14], 16, 2.8, MARBLE))
	# Desks, and the stacks he calls his reinforcements out of.
	for x in [-18, 18]:
		for z in [-80, -92, -104]:
			pieces.append(slab(o + Vector3(float(x), 0.6, float(z)), Vector3(5, 1.2, 3), ZoneBuilder.TIMBER))
	for x in [-22, 22]:
		pieces.append(slab(o + Vector3(float(x), 3, -70), Vector3(4, 6, 8), PARCHMENT))

	# --- The vault: The Bound Ledger, and four braziers, one per corner ---
	pieces.append_array(corridor(o + Vector3(0, 0, -124), 14, 26, 12, MARBLE_DARK))
	pieces.append_array(hall(o + Vector3(0, 0, -150), 56, 46, 18, MARBLE_DARK, "south"))
	# The braziers themselves, as geometry. The interactable that snuffs the ink
	# pools sits on top of these in the scene.
	for corner in [Vector3(-22, 0, -134), Vector3(22, 0, -134), Vector3(-22, 0, -166), Vector3(22, 0, -166)]:
		pieces.append(slab(o + corner + Vector3(0, 0.8, 0), Vector3(2.4, 1.6, 2.4), IRON))
		pieces.append(slab(o + corner + Vector3(0, 1.9, 0), Vector3(2.0, 0.6, 2.0), Color(0.90, 0.55, 0.18), false))
	# The ledger's plinth.
	pieces.append(slab(o + Vector3(0, 0.5, -156), Vector3(12, 1.0, 8), MARBLE))

	return pieces


## The Throne of Kingsmourn — the raid. An antechamber, then the throne room:
## the old king still lying in state, both claimants arrived at once, and the
## dais the raid has to stand on when the First King names someone.
static func throne_interior() -> Array:
	var o := THRONE_ORIGIN
	var pieces: Array = []

	pieces.append(slab(o + Vector3(0, -2, -60), Vector3(130, 2, 200), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 28, -60), Vector3(130, 2, 200), MARBLE_DARK))
	pieces.append(slab(o + Vector3(-64, 13, -60), Vector3(2, 32, 200), MARBLE_DARK))
	pieces.append(slab(o + Vector3(64, 13, -60), Vector3(2, 32, 200), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 13, 40), Vector3(130, 32, 2), MARBLE_DARK))
	pieces.append(slab(o + Vector3(0, 13, -160), Vector3(130, 32, 2), MARBLE_DARK))

	# Antechamber, where the claimants' guards are.
	pieces.append_array(hall(o + Vector3(0, 0, 6), 50, 56, 18, MARBLE, "north"))
	pieces.append_array(pillars(o + Vector3(0, 0, 6), [-17, 17], [-18, 0, 18], 18, 3.0, MARBLE))

	pieces.append_array(corridor(o + Vector3(0, 0, -38), 18, 32, 16, MARBLE))

	# --- The throne room ---
	pieces.append_array(hall(o + Vector3(0, 0, -100), 100, 90, 26, MARBLE, "south"))
	pieces.append_array(pillars(o + Vector3(0, 0, -100), [-36, 36], [-30, -10, 10, 30], 26, 3.6, MARBLE))
	# Both houses' banners down the long walls, hung the morning they both
	# arrived and found each other already there.
	for z in [-72, -96, -120]:
		pieces.append(slab(o + Vector3(-48, 15, float(z)), Vector3(0.6, 12, 6), STAG, false))
		pieces.append(slab(o + Vector3(48, 15, float(z)), Vector3(0.6, 12, 6), SUNBURST, false))

	# The dais. Three steps up, and the safe ground for the Crown mechanic.
	for i in range(3):
		var step := float(i)
		pieces.append(slab(o + Vector3(0, 0.4 + step * 0.8, -128 + step * 2.0), Vector3(34 - step * 6.0, 0.8, 22 - step * 4.0), MARBLE_DARK))
	# The throne, and the old king lying in state in front of it, unburied,
	# which is the reason for everything that happens in this game.
	pieces.append(slab(o + Vector3(0, 4.2, -136), Vector3(5, 6, 4), ZoneBuilder.GOLD))
	pieces.append(slab(o + Vector3(0, 3.4, -124), Vector3(11, 1.6, 5), MARBLE))
	pieces.append(slab(o + Vector3(0, 4.5, -124), Vector3(1.5, 0.7, 1.5), ZoneBuilder.GOLD, false))

	return pieces
