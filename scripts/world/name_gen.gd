class_name NameGen
## Generador de nombres procedurales para sistemas, planetas y especies.

const START := ["Ka", "Zor", "Ve", "Ul", "Thra", "Mo", "Ex", "Ny", "Ar", "Qui", "Sel", "Dro", "Ish", "Pa", "Gor", "Lu", "Rha", "Ob", "Ty", "Xe"]
const MID := ["la", "ri", "on", "va", "mer", "x", "the", "lo", "dra", "su", "ne", "ka", "vi", "qu", "an", "or"]
const END := ["ia", "us", "os", "ar", "ex", "on", "a", "is", "um", "ae", "ix", "or", "ea", " Prime", " IV", "-9", " Minor"]


static func generate(rng: RandomNumberGenerator) -> String:
	var s: String = START[rng.randi() % START.size()]
	for i in rng.randi_range(0, 2):
		s += MID[rng.randi() % MID.size()]
	s += END[rng.randi() % END.size()]
	return s
