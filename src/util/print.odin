package util

import "core:fmt"

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

print :: proc {
	printByteAsBinString,
	printDynamicBytesAsBinString,
	printBytesAsBinString,
}
