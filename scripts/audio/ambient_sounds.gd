extends RefCounted
## Small, original PCM placeholders; periodic loops and filtered transient recipes.
const RATE: int = 22050
static var _cache: Dictionary = {}
static func sound(kind: String) -> AudioStreamWAV:
	if _cache.has(kind): return _cache[kind]
	var loop := kind in ["ventilation","machinery","electrical"]
	var duration: float = 2.0 if loop else {"creak":1.7,"crash":1.3,"pipe":1.1,"startup":2.4,"malfunction":.9}.get(kind,1.0)
	var count := roundi(duration*RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed=631+kind.hash()
	var modes: Array[Vector3] = []
	for index in range(48 if kind=="ventilation" else 22):
		var frequency: float = (20+index*23+rng.randi_range(0,19))*.5
		if kind=="ventilation": frequency=(80+index*67+rng.randi_range(0,51))*.5
		if kind=="electrical": frequency=(50+index*50)*.5
		modes.append(Vector3(frequency,rng.randf()*TAU,1.0/pow(index+1,.35 if kind=="ventilation" else .8)))
	var noise: float = 0.0
	var phase: float = 0.0
	var peak: float = .001
	for index in range(count):
		var t := float(index)/RATE
		noise=lerpf(noise,rng.randf_range(-1,1),.12)
		var value: float = 0.0
		if loop:
			for mode in modes: value+=sin(TAU*mode.x*t+mode.y)*mode.z*.16
			value*=(.96+.04*cos(TAU*.5*t)) if kind=="ventilation" else (.88+.12*cos(TAU*t))
			if kind=="ventilation": value+=sin(TAU*173*t)*.025+sin(TAU*219*t)*.02
			elif kind=="machinery": value+=sin(TAU*48*t)*.22+sin(TAU*96*t)*.07
		else:
			match kind:
				"creak":
					phase+=TAU*(135+15*sin(t*8)+20*t)/RATE
					value=(sin(phase)+.2*sin(phase*2.13))*.2+noise*.12
				"crash":
					value=noise*.7*exp(-t*18)
					for mode in [67.0,121.0,239.0,477.0]: value+=sin(TAU*mode*t)*.18*exp(-t*(3+mode*.006))
				"pipe": value=(sin(TAU*176*t)+.3*sin(TAU*393*t))*.22*exp(-t*4)
				"startup": value=(sin(TAU*(40*t+8*t*t))*.2+noise*.25)*sin(PI*t/duration)
				"malfunction": value=(sin(TAU*117*t)*.17+noise*.35)*pow(.5+.5*sin(t*63),3)
			value*=minf(t/.035,1.0)*smoothstep(0.0,.15,duration-t)
		samples[index]=value
		peak=maxf(peak,absf(value))
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for index in range(count): bytes.encode_s16(index*2,roundi(samples[index]/peak*.35*32767))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.data=bytes
	if loop:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=count
	_cache[kind]=stream
	return stream
