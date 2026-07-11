package util

head :: proc(xs: []$T) -> (first: T, ok: bool) #optional_ok {
	if len(xs) < 1 {
		return
	}
	return xs[0], true
}
