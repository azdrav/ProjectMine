extends RefCounted
## Deterministic, band-limited PCM made once per sound, never in the flight loop.
const RATE: int = 22050
const BUS: StringName = &"IndustrialFX"
static var _cache: Dictionary = {}

static func ensure_bus() -> StringName:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,BUS)
		AudioServer.set_bus_send(index,&"Master")
		# Reserve headroom for the unchanged proximity tone and drone ambience.
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db=-8.0
		limiter.ceiling_db=-6.0
		AudioServer.add_bus_effect(index,limiter)
	return BUS

static func sound(kind: String) -> AudioStreamWAV:
	if _cache.has(kind): return _cache[kind]
	var duration: float = {"player_fire":.26,"enemy_fire":.16,"shield":.28,"impact":.38,"scrape":1.0}.get(kind,.2)
	var count := roundi(RATE*duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var random := RandomNumberGenerator.new()
	random.seed=1947+kind.hash()
	var partials: Array[Vector3] = []
	if kind=="scrape":
		for index in range(18):
			# Integer harmonics over exactly one second form a seamless grind loop.
			partials.append(Vector3(68+index*73+random.randi_range(0,35),random.randf()*TAU,.09/(1.0+index*.2)))
	var filtered_noise: float = 0.0
	var phase: float = 0.0
	var hp_input: float = 0.0
	var hp_output: float = 0.0
	var peak: float = .001
	for index in range(count):
		var time := float(index)/RATE
		var progress := time/duration
		filtered_noise=lerpf(filtered_noise,random.randf_range(-1,1),.24)
		var sample: float = 0.0
		match kind:
			"player_fire":
				# Four original layers, synthesized once: breech, discharge, energy, cabin ring.
				var mechanical := (filtered_noise*0.70 + sin(TAU*740*time)*0.18)*exp(-time*145.0)
				phase += TAU*(62.0+35.0*exp(-time*45.0))/RATE
				var bass := (sin(phase)*0.58+sin(phase*2.0)*0.20)*exp(-time*18.0)*minf(time/0.004,1.0)
				var electrical := sin(TAU*(530.0*time+650.0*(1.0-exp(-time*35.0))/35.0))*0.11*exp(-time*48.0)
				var resonance := (sin(TAU*185*time)+0.55*sin(TAU*307*time)+0.25*sin(TAU*493*time))*0.045*exp(-time*23.0)
				sample = (mechanical+bass+electrical+resonance)*minf(time/0.0015,1.0)
				# Gentle sub-bass/DC rejection; preserve headroom rather than boosting gain.
				hp_output = 0.9901*(hp_output+sample-hp_input)
				hp_input = sample
				sample = hp_output
			"enemy_fire":
				# Preserve the enemy recipe exactly; covered by the PCM hash regression.
				var base: float = 190.0
				phase+=TAU*(base+100.0+470.0*exp(-time*55.0))/RATE
				var transient := filtered_noise*1.8*exp(-time*115.0)
				var discharge := (sin(phase)+.24*sin(phase*2.01))*exp(-time*35.0)*.53
				var metal := (sin(TAU*base*2.7*time)+.4*sin(TAU*base*4.13*time))*exp(-time*32.0)*.11
				sample=(transient+discharge+metal)*minf(time/.0018,1.0)
			"shield":
				sample=filtered_noise*.65*exp(-time*35.0)
				sample+=(sin(TAU*210*time)+.32*sin(TAU*573*time))*exp(-time*24.0)*.26
				phase+=TAU*lerpf(760.0,150.0,progress)/RATE
				sample+=sin(phase)*exp(-time*19.0)*.22
				sample*=minf(time/.002,1.0)
			"impact":
				sample=filtered_noise*.8*exp(-time*75.0)
				for mode in [88.0,163.0,311.0,677.0]:
					sample+=sin(TAU*mode*time)*exp(-time*(15.0+mode*.017))*.19
				sample*=minf(time/.002,1.0)
			"scrape":
				for partial in partials: sample+=sin(TAU*partial.x*time+partial.y)*partial.z
				sample*=.8+.2*cos(TAU*4*time)
		if kind!="scrape": sample*=smoothstep(0.0,.03,duration-time)
		samples[index]=sample
		peak=maxf(peak,absf(sample))
	var data := PackedByteArray()
	data.resize(count*2)
	var amplitude: float = .24 if kind=="scrape" else .60 if kind=="player_fire" else .65
	for index in range(count): data.encode_s16(index*2,roundi(samples[index]/peak*amplitude*32767.0))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.data=data
	if kind=="scrape":
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=count
	_cache[kind]=stream
	return stream

static func player_cannon() -> AudioStreamWAV:
	# Recorded single-shot derivative; kept separate from the Guardian's procedural cannon.
	if not _cache.has("recorded_cannon"):
		_cache["recorded_cannon"] = load("res://assets/audio/player_cannon.wav")
	return _cache["recorded_cannon"]
