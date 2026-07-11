package util

import "core:fmt"
import "core:strings"

print_byte_as_bit_string :: proc(b: byte) {
	binString := fmt.tprintf("%08b", b)
	fmt.println(binString)
}

print_bytes_as_bit_string :: proc(bytes: []byte) {
	for i in bytes {
		print_byte_as_bit_string(i)
	}
	fmt.println("----------")
}

print_dynamic_bytes_as_bit_string :: proc(bytes: ^[dynamic]byte) {
	for i in bytes {
		print_byte_as_bit_string(i)
	}
	fmt.println("----------")
}

print_bytes_as_human_readable :: proc(bytes: []byte) {
	s := strings.repeat("-", len(bytes))
	fmt.println(s)
	for b in bytes {
		if b >= 32 && b <= 126 {
			fmt.print(rune(b), "")
		} else {
			fmt.print("<BIN>", "")
		}
	}
	fmt.println("")
	fmt.println(s)
}

print_bits :: proc {
	print_byte_as_bit_string,
	print_dynamic_bytes_as_bit_string,
	print_bytes_as_bit_string,
}

print :: proc {
	print_bytes_as_human_readable,
}
