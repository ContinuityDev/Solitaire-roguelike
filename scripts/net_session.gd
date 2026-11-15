class_name NetSession
extends Node

## Host-authoritative LAN (ENet). Host is always seat 0. Web builds cannot listen.

const PORT: int = 24567
const MAX_CLIENTS: int = 5
const PROTOCOL: int = 1

signal lobby_changed
signal match_started
signal snapshot_applied(data: Dictionary)
signal status_changed
signal server_lost
signal intent(data: Dictionary)

var active: bool = false
var is_host: bool = false
var local_seat: int = 0
var local_name: String = "You"
var status: String = ""
var peer_seat: Dictionary = {} # peer_id -> seat
var seat_peer: Dictionary = {} # seat -> peer_id
var lobby: LobbyConfig = null
var last_snapshot: Dictionary = {}
var join_ip: String = "127.0.0.1"
var in_match: bool = false

static func lan_supported() -> bool:
	return not OS.has_feature("web")

static func advertised_ips() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for a in IP.get_local_addresses():
		var s: String = str(a)
		if s.begins_with("127.") or s.begins_with("0.") or s.find(":") >= 0:
			continue
		out.append(s)
	if out.is_empty():
		out.append("127.0.0.1")
	return out

func is_client() -> bool:
	return active and not is_host

func is_remote_seat(seat: int) -> bool:
	if not active or not is_host:
		return false
	if seat == local_seat:
		return false
	return seat_peer.has(seat)

func seat_of_peer(peer_id: int) -> int:
	return int(peer_seat.get(peer_id, -1))

func _set_status(t: String) -> void:
	status = t
	status_changed.emit()

func host_listen(cfg: LobbyConfig, player_name: String) -> Error:
	close()
	if not lan_supported():
		_set_status("LAN needs the desktop build (not the web page).")
		return ERR_UNAVAILABLE
	lobby = cfg
	lobby.lan = true
	local_name = player_name.strip_edges()
	if local_name == "":
		local_name = "You"
	lobby.set_display_name(0, local_name)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		_set_status("Could not listen on %d (is another host open?)." % PORT)
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	local_seat = 0
	peer_seat[1] = 0
	seat_peer[0] = 1
	_bind_multiplayer()
	var ips: PackedStringArray = advertised_ips()
	_set_status("Listening on UDP %d  ·  %s" % [PORT, ", ".join(ips)])
	lobby_changed.emit()
	return OK

func join(ip: String, player_name: String) -> Error:
	close()
	if not lan_supported():
		_set_status("LAN join needs the desktop build.")
		return ERR_UNAVAILABLE
	join_ip = ip.strip_edges()
	if join_ip == "":
		join_ip = "127.0.0.1"
	local_name = player_name.strip_edges()
	if local_name == "":
		local_name = "Guest"
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(join_ip, PORT)
	if err != OK:
		_set_status("Could not reach %s:%d." % [join_ip, PORT])
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	local_seat = -1
	_bind_multiplayer()
	_set_status("Connecting to %s:%d…" % [join_ip, PORT])
	return OK

func close() -> void:
	_unbind_multiplayer()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	in_match = false
	local_seat = 0
	peer_seat.clear()
	seat_peer.clear()
	last_snapshot.clear()

func _bind_multiplayer() -> void:
	_unbind_multiplayer()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _unbind_multiplayer() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	if is_host:
		_set_status("Peer %d connected — waiting for a name." % id)

func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	var seat: int = seat_of_peer(id)
	peer_seat.erase(id)
	if seat > 0:
		seat_peer.erase(seat)
		if lobby != null:
			lobby.release_lan_seat(seat)
		intent.emit({"kind": "peer_left", "seat": seat})
		_broadcast_lobby()
		lobby_changed.emit()
		_set_status("%s left — seat is AI now." % ("Seat %d" % (seat + 1)))

func _on_connected_to_server() -> void:
	_set_status("Connected. Sending name…")
	hello.rpc_id(1, PROTOCOL, local_name)

func _on_connection_failed() -> void:
	_set_status("No host at %s:%d." % [join_ip, PORT])
	close()
	status_changed.emit()

func _on_server_disconnected() -> void:
	_set_status("Host left the table.")
	close()
	server_lost.emit()

@rpc("any_peer", "reliable")
func hello(proto: int, player_name: String) -> void:
	if not is_host or lobby == null:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if in_match:
		reject.rpc_id(peer_id, "Game already started.")
		return
	if proto != PROTOCOL:
		reject.rpc_id(peer_id, "This build does not match the host.")
		return
	if peer_seat.has(peer_id):
		return
	var n: String = player_name.strip_edges()
	if n == "":
		n = "P?"
	var seat: int = lobby.take_lan_seat(n)
	if seat < 0:
		reject.rpc_id(peer_id, "Table is full.")
		return
	peer_seat[peer_id] = seat
	seat_peer[seat] = peer_id
	welcome.rpc_id(peer_id, seat, lobby.to_dict())
	_broadcast_lobby()
	lobby_changed.emit()
	_set_status("%s sat as player %d." % [lobby.name_of(seat), seat + 1])

@rpc("authority", "reliable")
func welcome(seat: int, lobby_d: Dictionary) -> void:
	local_seat = seat
	lobby = LobbyConfig.from_dict(lobby_d)
	_set_status("You are player %d  ·  %s" % [seat + 1, lobby.name_of(seat)])
	lobby_changed.emit()

@rpc("authority", "reliable")
func reject(reason: String) -> void:
	_set_status(reason)
	close()
	status_changed.emit()

@rpc("authority", "reliable")
func lobby_sync(lobby_d: Dictionary) -> void:
	lobby = LobbyConfig.from_dict(lobby_d)
	lobby_changed.emit()

@rpc("authority", "reliable")
func begin_match() -> void:
	match_started.emit()

@rpc("authority", "reliable")
func apply_snapshot(data: Dictionary) -> void:
	last_snapshot = data
	if data.has("local_seat"):
		local_seat = int(data["local_seat"])
	snapshot_applied.emit(data)

@rpc("any_peer", "reliable")
func req_intent(data: Dictionary) -> void:
	if not is_host:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var seat: int = seat_of_peer(peer_id)
	if seat < 0:
		return
	var payload: Dictionary = data.duplicate()
	payload["seat"] = seat
	intent.emit(payload)

func send_intent(data: Dictionary) -> void:
	if not is_client():
		return
	req_intent.rpc_id(1, data)

func announce_match() -> void:
	if is_host:
		in_match = true
		begin_match.rpc()

func _broadcast_lobby() -> void:
	if not is_host or lobby == null:
		return
	lobby_sync.rpc(lobby.to_dict())

func push_renames() -> void:
	if is_host:
		_broadcast_lobby()
		lobby_changed.emit()

func kick_seat(seat: int) -> void:
	if not is_host or seat <= 0:
		return
	var pid: int = int(seat_peer.get(seat, -1))
	if pid > 1 and multiplayer.multiplayer_peer != null:
		reject.rpc_id(pid, "Host dropped you.")
		multiplayer.multiplayer_peer.disconnect_peer(pid)
		return
	if lobby != null:
		lobby.release_lan_seat(seat)
	_broadcast_lobby()
	lobby_changed.emit()

func broadcast_to_clients(builder: Callable) -> void:
	if not is_host:
		return
	for peer_id in peer_seat.keys():
		var id: int = int(peer_id)
		if id == 1:
			continue
		var seat: int = int(peer_seat[id])
		var d: Dictionary = builder.call(seat)
		d["local_seat"] = seat
		apply_snapshot.rpc_id(id, d)
