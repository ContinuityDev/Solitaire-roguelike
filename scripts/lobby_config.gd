class_name LobbyConfig
extends RefCounted

## Local cabinet: 2–6 seats, each Human or AI. Hotseat on one device.

const MIN_SEATS: int = 2
const MAX_SEATS: int = 6
const KIND_HUMAN := "human"
const KIND_AI := "ai"

var lobby_name: String = "The Cabinet"
var lobby_code: String = ""
var seat_count: int = 6
var kinds: Array = [] # "human" | "ai", length seat_count
var display_names: Array = []

func _init() -> void:
	lobby_code = make_code()
	_resize(6)
	kinds[0] = KIND_HUMAN
	for i in range(1, 6):
		kinds[i] = KIND_AI
	display_names = RunManager.NAMES.duplicate()

static func solo() -> LobbyConfig:
	var c: LobbyConfig = LobbyConfig.new()
	c.lobby_name = "Solo"
	c.seat_count = 6
	c.kinds = [KIND_HUMAN, KIND_AI, KIND_AI, KIND_AI, KIND_AI, KIND_AI]
	c.display_names = RunManager.NAMES.duplicate()
	return c

static func make_code() -> String:
	var alphabet: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var out: String = ""
	for _i in range(4):
		out += alphabet[rng.randi_range(0, alphabet.length() - 1)]
	return out

func _resize(n: int) -> void:
	n = clampi(n, MIN_SEATS, MAX_SEATS)
	seat_count = n
	while kinds.size() < MAX_SEATS:
		kinds.append(KIND_AI)
	while display_names.size() < MAX_SEATS:
		display_names.append("Seat %d" % display_names.size())
	if kinds.size() > MAX_SEATS:
		kinds.resize(MAX_SEATS)
	if display_names.size() > MAX_SEATS:
		display_names.resize(MAX_SEATS)
	if kinds.is_empty() or str(kinds[0]) != KIND_HUMAN:
		kinds[0] = KIND_HUMAN

func set_seat_count(n: int) -> void:
	_resize(n)
	# Host stays human. New seats default to AI.
	for i in range(seat_count):
		if str(kinds[i]) != KIND_HUMAN and str(kinds[i]) != KIND_AI:
			kinds[i] = KIND_AI
	_fill_default_names()

func _fill_default_names() -> void:
	while display_names.size() < MAX_SEATS:
		display_names.append("")
	var h: int = 1
	var multi: bool = human_count() > 1
	for i in range(MAX_SEATS):
		if i >= seat_count:
			continue
		if is_human(i):
			display_names[i] = "You" if not multi else "P%d" % h
			h += 1
		else:
			display_names[i] = str(RunManager.NAMES[i]) if i < RunManager.NAMES.size() else "AI %d" % i

func set_kind(seat: int, kind: String) -> void:
	if seat < 0 or seat >= MAX_SEATS:
		return
	if seat == 0:
		kinds[0] = KIND_HUMAN
		return
	if kind != KIND_HUMAN and kind != KIND_AI:
		return
	kinds[seat] = kind
	_fill_default_names()

func fill_empty_with_ai() -> void:
	for i in range(seat_count):
		var k: String = str(kinds[i])
		if k != KIND_HUMAN:
			kinds[i] = KIND_AI
	_fill_default_names()

func is_human(seat: int) -> bool:
	if seat < 0 or seat >= seat_count:
		return false
	return str(kinds[seat]) == KIND_HUMAN

func is_ai(seat: int) -> bool:
	if seat < 0 or seat >= seat_count:
		return false
	return str(kinds[seat]) == KIND_AI

func human_seats() -> Array:
	var out: Array = []
	for i in range(seat_count):
		if is_human(i):
			out.append(i)
	return out

func ai_seats() -> Array:
	var out: Array = []
	for i in range(seat_count):
		if is_ai(i):
			out.append(i)
	return out

func human_count() -> int:
	return human_seats().size()

func is_hotseat() -> bool:
	return human_count() > 1

func can_start() -> bool:
	return seat_count >= MIN_SEATS and seat_count <= MAX_SEATS and human_count() >= 1

func name_of(seat: int) -> String:
	if seat >= 0 and seat < display_names.size() and str(display_names[seat]) != "":
		return str(display_names[seat])
	if seat >= 0 and seat < RunManager.NAMES.size():
		return str(RunManager.NAMES[seat])
	return "Seat %d" % seat

## True when the device must be passed before `to_seat` may see their hand.
static func needs_handoff(config: LobbyConfig, view_seat: int, to_seat: int) -> bool:
	if config == null:
		return false
	if not config.is_hotseat():
		return false
	if not config.is_human(to_seat):
		return false
	return view_seat != to_seat

static func is_human_turn(config: LobbyConfig, seat: int) -> bool:
	return config != null and config.is_human(seat)
