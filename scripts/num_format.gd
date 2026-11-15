class_name NumFormat
extends RefCounted

## Compact labels for escalating card ranks / powers (Balatro-style go-up).
## Under 1000: plain int. Then K / M / B / T. Beyond that: scientific.

static func compact(n: int) -> String:
	var sign: String = "-" if n < 0 else ""
	var a: int = absi(n)
	if a < 1000:
		return "%s%d" % [sign, a]
	if a < 1_000_000:
		return sign + _trim1(float(a) / 1000.0) + "K"
	if a < 1_000_000_000:
		return sign + _trim1(float(a) / 1_000_000.0) + "M"
	if a < 1_000_000_000_000:
		return sign + _trim1(float(a) / 1_000_000_000.0) + "B"
	if a < 1_000_000_000_000_000:
		return sign + _trim1(float(a) / 1_000_000_000_000.0) + "T"
	# Scientific once past trillions — keeps card faces readable.
	return "%s%.2e" % [sign, float(a)]

static func _trim1(v: float) -> String:
	var s: String = "%.1f" % v
	if s.ends_with(".0"):
		return s.substr(0, s.length() - 2)
	return s
