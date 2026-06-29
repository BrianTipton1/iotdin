package util

import "core:fmt"
import "core:strings"

printByteAsBinString :: proc(b: byte) {
	binString := fmt.tprintf("%08b", b)
	fmt.println(binString)
}

printBytesAsBinString :: proc(bytes: []byte) {
	for i in bytes {
		printByteAsBinString(i)
	}
	fmt.println("----------")
}

printDynamicBytesAsBinString :: proc(bytes: ^[dynamic]byte) {
	for i in bytes {
		printByteAsBinString(i)
	}
	fmt.println("----------")
}

print_bin_string :: proc {
	printByteAsBinString,
	printDynamicBytesAsBinString,
	printBytesAsBinString,
}

printBytesAsHumanReadable :: proc(bytes: []byte) {
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
print :: proc {
	printBytesAsHumanReadable,
}
