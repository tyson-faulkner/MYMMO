# PartyManager — who is grouped with whom, and who therefore gets credit.
#
# The single most important thing this fixes: before it existed, only whoever
# landed the killing blow got XP and quest credit. In a game built for five to
# ten friends, that meant grouping up actively punished you — four people
# fighting the same camp each needed their own kills. Nobody would ever group.
#
# Parties live on the SERVER. Clients are told the roster and nothing else.
# Design doc rules that shape this: dungeons are five players and must work with
# four, the raid is five with a possible ten, and boss scaling already reads how
# many players are present — so the cap here is ten, matching MAX_PLAYERS.
extends Node

signal party_changed(party_id: int, members: Array)

## Design doc: raid is 5, "with a possible 10-player option".
const MAX_PARTY_SIZE := 10

## Everyone within this range of the killer shares the reward. Generous enough
## that a healer at the back still counts.
const SHARE_RANGE := 60.0

## party_id -> Array[int] of peer ids. The first entry is the leader.
var parties: Dictionary = {}
## peer_id -> party_id, so lookups don't scan.
var membership: Dictionary = {}

var _next_party_id: int = 1


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func party_of(peer_id: int) -> int:
	return int(membership.get(peer_id, 0))


func members_of(peer_id: int) -> Array:
	var party_id := party_of(peer_id)
	if party_id == 0:
		return [peer_id]
	return parties.get(party_id, [peer_id])


func is_grouped(peer_id: int) -> bool:
	return party_of(peer_id) != 0


func leader_of(party_id: int) -> int:
	var members: Array = parties.get(party_id, [])
	return int(members[0]) if not members.is_empty() else 0


# --- Forming and breaking parties ------------------------------------------


## Server-side. Put two players in a party together, creating one if needed.
func add_to_party(inviter_peer_id: int, invitee_peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if inviter_peer_id == invitee_peer_id or invitee_peer_id <= 0:
		return false
	if is_grouped(invitee_peer_id):
		return false

	var party_id := party_of(inviter_peer_id)
	if party_id == 0:
		party_id = _next_party_id
		_next_party_id += 1
		parties[party_id] = [inviter_peer_id]
		membership[inviter_peer_id] = party_id

	var members: Array = parties[party_id]
	if members.size() >= MAX_PARTY_SIZE:
		return false
	members.append(invitee_peer_id)
	parties[party_id] = members
	membership[invitee_peer_id] = party_id
	_broadcast(party_id)
	return true


func leave_party(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var party_id := party_of(peer_id)
	if party_id == 0:
		return
	var members: Array = parties.get(party_id, [])
	members.erase(peer_id)
	membership.erase(peer_id)
	# A party of one is not a party.
	if members.size() <= 1:
		for remaining in members:
			membership.erase(remaining)
		parties.erase(party_id)
		_broadcast_disbanded(party_id, members)
		return
	parties[party_id] = members
	_broadcast(party_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		leave_party(peer_id)


func _broadcast(party_id: int) -> void:
	var members: Array = parties.get(party_id, [])
	party_changed.emit(party_id, members)
	sync_party.rpc(party_id, members)


func _broadcast_disbanded(party_id: int, members: Array) -> void:
	party_changed.emit(party_id, [])
	sync_party.rpc(party_id, [])
	for peer_id in members:
		sync_party.rpc(0, [])


@rpc("authority", "reliable")
func sync_party(party_id: int, members: Array) -> void:
	if multiplayer.is_server():
		return
	if members.is_empty():
		parties.erase(party_id)
		for peer_id in membership.keys():
			if int(membership[peer_id]) == party_id:
				membership.erase(peer_id)
	else:
		parties[party_id] = members
		for peer_id in members:
			membership[int(peer_id)] = party_id
	party_changed.emit(party_id, members)


# --- Sharing the spoils ----------------------------------------------------


## Everyone who should be credited for a kill: the killer, plus any party member
## close enough to have plausibly been in the fight.
##
## Solo, this returns just the killer, so nothing changes for someone playing
## alone.
func share_group_for(killer_peer_id: int, where: Vector3, players_root: Node) -> Array:
	var members := members_of(killer_peer_id)
	if members.size() <= 1:
		return [killer_peer_id]
	var nearby: Array = []
	for peer_id in members:
		var body := _find_body(int(peer_id), players_root)
		if body == null:
			continue
		var stats := body.get_node_or_null("Stats") as Stats
		if stats and stats.is_dead:
			# Ghosts don't get paid.
			continue
		if body.global_position.distance_to(where) <= SHARE_RANGE:
			nearby.append(int(peer_id))
	if nearby.is_empty():
		return [killer_peer_id]
	return nearby


## XP is split so a group doesn't level twice as fast as a solo player, but the
## split is generous: grouping should never be worse than going alone, and
## should usually be better because you kill faster and die less.
static func experience_share(total: int, party_size: int) -> int:
	if party_size <= 1:
		return total
	var share := float(total) * (1.0 + 0.35 * float(party_size - 1)) / float(party_size)
	return maxi(1, int(round(share)))


func _find_body(peer_id: int, players_root: Node) -> Node3D:
	if players_root == null:
		return null
	return players_root.get_node_or_null(str(peer_id)) as Node3D
