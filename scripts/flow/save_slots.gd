extends RefCounted
## Shared, read-only save validation also works before a level/player exists.
static var directory := "user://saves"
static var legacy_path := "user://signal_lost_v1.json"
const IDS := ["lower","upper","deep_2","deep_3","deep_4","deep_5","deep_6","deep_7","deep_8","deep_9"]
static func manual(slot: int) -> String: return directory+"/slot_%d.json"%clampi(slot,1,3)
static func checkpoint() -> String: return directory+"/checkpoint.json"
static func numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for n in value:
		if not (n is float or n is int) or not is_finite(float(n)): return false
	return true
static func validate(d: Variant) -> bool:
	if not d is Dictionary: return false
	if not numbers([d.get("version")],1) or d.version<1 or d.version>4 or d.version!=floor(d.version): return false
	if not numbers(d.get("position"),3) or not numbers(d.get("basis"),9): return false
	var b: Array = d.basis
	var basis := Basis(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]),Vector3(b[6],b[7],b[8]))
	if absf(basis.determinant())<0.01: return false
	if not numbers([d.get("shield"),d.get("energy"),d.get("objective")],3): return false
	if d.shield<0 or d.shield>100 or d.energy<0 or d.energy>100: return false
	if d.objective<0 or d.objective>(7 if d.version==4 else 6) or d.objective!=floor(d.objective): return false
	for key in ["terminal","generator","door","security"]:
		if not d.get(key) is bool: return false
	if d.terminal!=(d.objective>=3) or d.generator!=(d.objective>=4) or d.door!=(d.objective>=5) or d.security!=(d.objective>=6): return false
	if d.version>=2:
		if not numbers([d.get("ammo")],1) or d.ammo<0 or d.ammo>200 or d.ammo!=floor(d.ammo): return false
	if d.version>=3:
		if not numbers([d.get("missiles")],1) or d.missiles<0 or d.missiles>12 or d.missiles!=floor(d.missiles): return false
	if not d.get("destroyed") is Dictionary: return false
	for id in d.destroyed:
		if id not in IDS or d.destroyed[id]!=true: return false
	if d.has("expansion") and not valid_expansion(d.expansion): return false
	if d.version==4:
		if d.has("run_id") and (not d.run_id is String or d.run_id.length()>96): return false
		if not numbers([d.get("elapsed")],1) or d.elapsed<0: return false
		if not valid_escape(d.get("escape"),int(d.objective)): return false
	return true
static func valid_expansion(d: Variant) -> bool:
	if not d is Dictionary or not d.get("pickups") is Dictionary or not d.get("collected") is Dictionary: return false
	if d.pickups.size()>30 or d.collected.size()>30: return false
	for id in d.pickups:
		if id not in ["cache_0","cache_1","cache_2","missile_cache_0","missile_cache_1"] and not (str(id).begins_with("drop_") and str(id).trim_prefix("drop_") in IDS): return false
		var entry: Variant = d.pickups[id]
		if not entry is Dictionary or not numbers(entry.get("position"),3) or not numbers([entry.get("amount")],1): return false
		if entry.amount<1 or entry.amount>200 or entry.amount!=floor(entry.amount): return false
		if entry.get("kind","ammo") not in ["ammo","missiles"]: return false
	for id in d.collected:
		if not d.pickups.has(id) or d.collected[id]!=true: return false
	return true
static func valid_escape(e: Variant, objective: int) -> bool:
	if not e is Dictionary or not numbers([e.get("phase"),e.get("remaining"),e.get("duration"),e.get("stage")],4): return false
	if e.phase<0 or e.phase>2 or e.phase!=floor(e.phase) or e.stage<0 or e.stage>6 or e.stage!=floor(e.stage): return false
	if e.duration<10 or e.duration>3600 or e.remaining<0 or e.remaining>e.duration: return false
	if (objective<6 and (e.phase!=0 or e.stage!=0)) or (objective==6 and (e.phase!=1 or e.remaining<=0)) or (objective==7 and (e.phase!=2 or e.stage!=6)): return false
	if not e.get("zones") is Array or e.zones.size()>6: return false
	if e.phase==0 and (not e.zones.is_empty() or e.remaining!=e.duration): return false
	var seen := []
	for id in e.zones:
		if not numbers([id],1) or id<0 or id>=e.stage or id>5 or id!=floor(id) or int(id) in seen: return false
		seen.append(int(id))
	return true
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1048576: return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if validate(data) else {}
static func resumable(path: String) -> bool:
	var data := read(path)
	return not data.is_empty() and data.shield>0
static func latest() -> String:
	var best := ""
	var newest := -1.0
	for path in [manual(1),manual(2),manual(3),checkpoint(),legacy_path]:
		var data := read(path)
		if data.is_empty() or data.shield<=0: continue
		var date := float(data.get("saved_at",FileAccess.get_modified_time(path)))
		if date>newest: newest=date;best=path
	return best
static func description(path: String) -> String:
	var data := read(path)
	if data.is_empty(): return "EMPTY / INVALID"
	return "Objective %d  •  Shield %d%%  •  Ammo %d"%[int(data.objective)+1,int(data.shield),int(data.get("ammo",120))]
