class_name MqttWs
extends Node

## Tiny MQTT 3.1.1 client over WebSocket. Signaling only — not game traffic.

signal connected
signal failed(reason: String)
signal message(topic: String, payload: String)

const BROKERS: Array = [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
]

var _ws: WebSocketPeer
var _topic: String = ""
var _client_id: String = ""
var _opened: bool = false
var _authed: bool = false
var _broker_i: int = 0
var _ping_acc: float = 0.0
var _sub_id: int = 1

func is_ready() -> bool:
	return _authed

func start(topic: String, client_id: String) -> void:
	stop()
	_topic = topic
	_client_id = client_id
	_broker_i = 0
	_connect_current()

func stop() -> void:
	_opened = false
	_authed = false
	if _ws != null:
		_ws.close()
		_ws = null

func publish(payload: String) -> void:
	if not _authed or _ws == null:
		return
	var body: PackedByteArray = _utf( _topic)
	body.append_array(payload.to_utf8_buffer())
	_ws.put_packet(_pack(0x30, body))

func _connect_current() -> void:
	_ws = WebSocketPeer.new()
	_ws.supported_protocols = PackedStringArray(["mqtt"])
	var url: String = str(BROKERS[_broker_i])
	var err: Error = _ws.connect_to_url(url)
	if err != OK:
		_try_next("Could not open %s (%d)." % [url, err])

func _try_next(reason: String) -> void:
	_broker_i += 1
	if _broker_i >= BROKERS.size():
		failed.emit(reason)
		return
	_connect_current()

func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st: int = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _opened:
			_opened = true
			_send_connect()
		while _ws.get_available_packet_count() > 0:
			_on_packet(_ws.get_packet())
		if _authed:
			_ping_acc += delta
			if _ping_acc >= 25.0:
				_ping_acc = 0.0
				_ws.put_packet(PackedByteArray([0xC0, 0x00]))
	elif st == WebSocketPeer.STATE_CLOSED:
		if _authed:
			failed.emit("Signaling dropped.")
			_authed = false
		elif _opened:
			_try_next("Broker closed the socket.")
		_opened = false

func _send_connect() -> void:
	var proto: PackedByteArray = _utf("MQTT")
	var rest: PackedByteArray = PackedByteArray()
	rest.append_array(proto)
	rest.append(4) # protocol level 3.1.1
	rest.append(0x02) # clean session
	rest.append(0)
	rest.append(60) # keep-alive
	rest.append_array(_utf(_client_id))
	_ws.put_packet(_pack(0x10, rest))

func _on_packet(pkt: PackedByteArray) -> void:
	if pkt.is_empty():
		return
	var kind: int = pkt[0] & 0xF0
	if kind == 0x20: # CONNACK
		if pkt.size() >= 4 and pkt[3] == 0:
			_authed = true
			_send_subscribe()
			connected.emit()
		else:
			_try_next("MQTT connect refused.")
	elif kind == 0x90: # SUBACK
		pass
	elif kind == 0x30: # PUBLISH
		var qos: int = (pkt[0] >> 1) & 0x03
		var off: int = 1
		var dec: Dictionary = _dec_len(pkt, off)
		off = int(dec["next"])
		if pkt.size() < off + 2:
			return
		var tlen: int = (pkt[off] << 8) | pkt[off + 1]
		off += 2
		if pkt.size() < off + tlen:
			return
		var topic: String = pkt.slice(off, off + tlen).get_string_from_utf8()
		off += tlen
		if qos > 0:
			off += 2
		var payload: String = pkt.slice(off).get_string_from_utf8()
		message.emit(topic, payload)

func _send_subscribe() -> void:
	_sub_id += 1
	var rest: PackedByteArray = PackedByteArray()
	rest.append((_sub_id >> 8) & 0xFF)
	rest.append(_sub_id & 0xFF)
	rest.append_array(_utf(_topic))
	rest.append(0) # QoS 0
	_ws.put_packet(_pack(0x82, rest))

static func encode_remaining_length(n: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var x: int = maxi(0, n)
	while true:
		var b: int = x % 128
		x = int(x / 128)
		if x > 0:
			b |= 0x80
		out.append(b)
		if x <= 0:
			break
	return out

static func topic_for(code: String) -> String:
	var c: String = code.strip_edges().to_upper()
	return "continuity-president/%s" % c

static func _utf(s: String) -> PackedByteArray:
	var b: PackedByteArray = s.to_utf8_buffer()
	var out: PackedByteArray = PackedByteArray()
	out.append((b.size() >> 8) & 0xFF)
	out.append(b.size() & 0xFF)
	out.append_array(b)
	return out

static func _pack(header: int, body: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.append(header)
	out.append_array(encode_remaining_length(body.size()))
	out.append_array(body)
	return out

static func _dec_len(pkt: PackedByteArray, start: int) -> Dictionary:
	var mul: int = 1
	var value: int = 0
	var i: int = start
	while i < pkt.size():
		var b: int = pkt[i]
		i += 1
		value += (b & 127) * mul
		if (b & 128) == 0:
			break
		mul *= 128
	return {"len": value, "next": i}
