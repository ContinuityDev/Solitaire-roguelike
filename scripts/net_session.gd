class_name NetSession
extends Node

## Host-authoritative table. Web uses WebRTC (join by table code).
## Desktop uses ENet LAN (join by IP). Host is always seat 0.

const PORT: int = 24567
const MAX_CLIENTS: int = 5
const PROTOCOL: int = 1
const STUN: Dictionary = {
	"iceServers": [
		{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
	],
}

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
var join_code: String = ""
var in_match: bool = false

var _rtc: WebRTCMultiplayerPeer
var _mqtt: MqttWs
var _uid: String = ""
var _next_peer_id: int = 2
var _use_webrtc: bool = false
var _pending: Array = [] # signaling msgs before the peer exists
var _seen_uids: Dictionary = {}

static func lan_supported() -> bool:
	return true

static func uses_webrtc() -> bool:
	return OS.has_feature("web")

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
	lobby = cfg
	lobby.lan = true
	local_name = player_name.strip_edges()
	if local_name == "":
		local_name = "You"
	lobby.set_display_name(0, local_name)
	if uses_webrtc():
		return _host_webrtc()
	return _host_enet()

func join(target: String, player_name: String) -> Error:
	close()
	local_name = player_name.strip_edges()
	if local_name == "":
		local_name = "Guest"
	if uses_webrtc():
		return _join_webrtc(target)
	return _join_enet(target)

func _host_enet() -> Error:
	_use_webrtc = false
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		_set_status("Could not listen on %d (is another host open?)." % PORT)
		return err
	multiplayer.multiplayer_peer = peer
	_mark_host_ready()
	var ips: PackedStringArray = advertised_ips()
	_set_status("LAN UDP %d  ·  %s" % [PORT, ", ".join(ips)])
	lobby_changed.emit()
	return OK

func _join_enet(ip: String) -> Error:
	_use_webrtc = false
	join_ip = ip.strip_edges()
	if join_ip == "":
		join_ip = "127.0.0.1"
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

func _host_webrtc() -> Error:
	_use_webrtc = true
	_rtc = WebRTCMultiplayerPeer.new()
	var err: Error = _rtc.create_server()
	if err != OK:
		_set_status("WebRTC host failed (%d)." % err)
		return err
	multiplayer.multiplayer_peer = _rtc
	_mark_host_ready()
	_uid = "host"
	_next_peer_id = 2
	_start_mqtt(lobby.lobby_code)
	_set_status("Table code %s — others Join with this code on the same page." % lobby.lobby_code)
	lobby_changed.emit()
	return OK

func _join_webrtc(code: String) -> Error:
	_use_webrtc = true
	join_code = code.strip_edges().to_upper()
	if join_code.length() != 4:
		_set_status("Need the host’s 4-letter table code.")
		return ERR_INVALID_PARAMETER
	_uid = "j%s%d" % [join_code, randi() % 100000]
	active = true
	is_host = false
	local_seat = -1
	_set_status("Looking for table %s…" % join_code)
	_start_mqtt(join_code)
	return OK

func _mark_host_ready() -> void:
	active = true
	is_host = true
	local_seat = 0
	peer_seat[1] = 0
	seat_peer[0] = 1
	_bind_multiplayer()

func _start_mqtt(code: String) -> void:
	if _mqtt == null:
		_mqtt = MqttWs.new()
		_mqtt.name = "MqttWs"
		add_child(_mqtt)
		_mqtt.connected.connect(_on_mqtt_connected)
		_mqtt.failed.connect(_on_mqtt_failed)
		_mqtt.message.connect(_on_mqtt_message)
	var cid: String = "pres-%s-%d" % [code.to_upper(), Time.get_ticks_msec() % 100000]
	_mqtt.start(MqttWs.topic_for(code), cid)

func _on_mqtt_connected() -> void:
	if is_host:
		_sig_pub({"t": "host", "name": local_name, "code": lobby.lobby_code if lobby else ""})
		_set_status("Live. Table code %s — share it." % (lobby.lobby_code if lobby else join_code))
	else:
		_sig_pub({"t": "join", "uid": _uid, "name": local_name})
		_set_status("Sat in the waiting room for %s…" % join_code)

func _on_mqtt_failed(reason: String) -> void:
	_set_status("Could not reach a signaling broker. %s" % reason)
	if not is_host:
		close()
		status_changed.emit()

func _sig_pub(d: Dictionary) -> void:
	if _mqtt:
		_mqtt.publish(JSON.stringify(d))

func _on_mqtt_message(_topic: String, payload: String) -> void:
	var parsed: Variant = JSON.parse_string(payload)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed
	var kind: String = str(msg.get("t", ""))
	match kind:
		"join":
			if is_host:
				_host_got_join(msg)
		"assign":
			if not is_host and str(msg.get("uid", "")) == _uid:
				_client_got_assign(int(msg.get("id", 0)))
		"offer":
			_got_sdp("offer", msg)
		"answer":
			_got_sdp("answer", msg)
		"ice":
			_got_ice(msg)
		"host":
			if not is_host and _rtc == null:
				_sig_pub({"t": "join", "uid": _uid, "name": local_name})

func _host_got_join(msg: Dictionary) -> void:
	if in_match:
		return
	var uid: String = str(msg.get("uid", ""))
	if uid == "" or uid == "host":
		return
	if _seen_uids.has(uid):
		return
	_seen_uids[uid] = true
	var id: int = _next_peer_id
	_next_peer_id += 1
	_create_rtc_peer(id)
	_sig_pub({"t": "assign", "uid": uid, "id": id})
	_set_status("Linking a joiner as peer %d…" % id)

func _client_got_assign(id: int) -> void:
	if id < 2:
		_set_status("Host rejected the sit-down.")
		return
	if _rtc != null:
		return
	_rtc = WebRTCMultiplayerPeer.new()
	var err: Error = _rtc.create_client(id)
	if err != OK:
		_set_status("WebRTC client failed (%d)." % err)
		return
	multiplayer.multiplayer_peer = _rtc
	_bind_multiplayer()
	_create_rtc_peer(1)
	_flush_pending()
	_set_status("Negotiating a private table link…")

func _create_rtc_peer(id: int) -> WebRTCPeerConnection:
	var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
	peer.initialize(STUN)
	peer.session_description_created.connect(func(type: String, sdp: String) -> void:
		if _rtc == null or not _rtc.has_peer(id):
			return
		_rtc.get_peer(id).connection.set_local_description(type, sdp)
		if type == "offer":
			_sig_pub({"t": "offer", "from": _rtc.get_unique_id(), "to": id, "sdp": sdp})
		else:
			_sig_pub({"t": "answer", "from": _rtc.get_unique_id(), "to": id, "sdp": sdp})
	)
	peer.ice_candidate_created.connect(func(mid: String, index: int, sdp: String) -> void:
		if _rtc == null:
			return
		_sig_pub({
			"t": "ice",
			"from": _rtc.get_unique_id(),
			"to": id,
			"mid": mid,
			"index": index,
			"sdp": sdp,
		})
	)
	_rtc.add_peer(peer, id)
	if id < _rtc.get_unique_id():
		peer.create_offer()
	return peer

func _got_sdp(kind: String, msg: Dictionary) -> void:
	if _rtc == null:
		_pending.append(msg)
		return
	var from_id: int = int(msg.get("from", 0))
	var to_id: int = int(msg.get("to", 0))
	if to_id != 0 and to_id != _rtc.get_unique_id():
		return
	if not _rtc.has_peer(from_id):
		_pending.append(msg)
		return
	_rtc.get_peer(from_id).connection.set_remote_description(kind, str(msg.get("sdp", "")))

func _got_ice(msg: Dictionary) -> void:
	if _rtc == null:
		_pending.append(msg)
		return
	var from_id: int = int(msg.get("from", 0))
	var to_id: int = int(msg.get("to", 0))
	if to_id != 0 and to_id != _rtc.get_unique_id():
		return
	if not _rtc.has_peer(from_id):
		_pending.append(msg)
		return
	_rtc.get_peer(from_id).connection.add_ice_candidate(
		str(msg.get("mid", "")), int(msg.get("index", 0)), str(msg.get("sdp", "")))

func _flush_pending() -> void:
	var left: Array = _pending.duplicate()
	_pending.clear()
	for m in left:
		var msg: Dictionary = m
		var kind: String = str(msg.get("t", ""))
		if kind == "offer" or kind == "answer":
			_got_sdp(kind, msg)
		elif kind == "ice":
			_got_ice(msg)

func _process(_delta: float) -> void:
	if _rtc == null:
		return
	for pid in _rtc.get_peers().keys():
		var info: Dictionary = _rtc.get_peer(int(pid))
		if info.has("connection") and info["connection"] is WebRTCPeerConnection:
			(info["connection"] as WebRTCPeerConnection).poll()

func close() -> void:
	_unbind_multiplayer()
	if _mqtt != null:
		_mqtt.stop()
	if _rtc != null:
		_rtc.close()
		_rtc = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	in_match = false
	_use_webrtc = false
	local_seat = 0
	peer_seat.clear()
	seat_peer.clear()
	last_snapshot.clear()
	_pending.clear()
	_seen_uids.clear()
	_next_peer_id = 2

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
	if _rtc != null and _rtc.has_peer(id):
		_rtc.remove_peer(id)
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
	if _use_webrtc:
		_set_status("Could not punch a WebRTC path to the host. Try the same Wi-Fi.")
	else:
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
	if pid > 1:
		reject.rpc_id(pid, "Host dropped you.")
		if _rtc != null and _rtc.has_peer(pid):
			_rtc.remove_peer(pid)
		elif multiplayer.multiplayer_peer != null:
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
