extends RefCounted
## Cached drone ambience/events; weapon fire uses the shared industrial recipes.
const IndustrialSounds = preload("res://scripts/audio/industrial_sounds.gd")
static var _cache: Dictionary = {}
static func sound(kind: String) -> AudioStreamWAV:
	if kind=="fire": return IndustrialSounds.sound("enemy_fire")
	if _cache.has(kind): return _cache[kind]
	var duration: float = {"engine": 0.2, "alert": 0.28, "hit": 0.13, "destroy": 0.65}.get(kind, 0.15)
	var count := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 731
	for index in range(count):
		var time := float(index) / 22050.0
		var progress := time / duration
		var frequency: float = 80.0
		match kind:
			"alert": frequency = 650.0 if progress < 0.5 else 1000.0
			"hit": frequency = lerpf(380.0, 110.0, progress)
			"destroy": frequency = lerpf(160.0, 35.0, progress)
		phase += TAU * frequency / 22050.0
		var sample := sin(phase) * 0.12
		if kind == "engine": sample = sin(TAU*80*time)*0.06 + sin(TAU*160*time)*0.025
		elif kind == "destroy":
			sample = sin(TAU*(65*time+18*(1-exp(-time*35))/35))*.32*exp(-time*7)
			sample += random.randf_range(-0.22,0.22)*exp(-time*26)
			sample += (sin(TAU*173*time)+sin(TAU*311*time)*.4)*.07*exp(-time*12)
		elif kind == "hit": sample += random.randf_range(-0.15, 0.15)
		if kind != "engine": sample *= minf(time / 0.006, 1.0) * pow(1.0-progress, 1.5)
		data.encode_s16(index*2, roundi(clampf(sample,-0.8,0.8)*32767.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = 22050
	result.data = data
	if kind == "engine":
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_end = count
	_cache[kind] = result
	return result
