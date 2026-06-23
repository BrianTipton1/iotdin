package main

import "core:fmt"
import "protocol"
import "util"


main :: proc() {
	fmt.println()

	buf := make([dynamic]byte)
	defer delete(buf)
	x := protocol.serialize(
		&buf,
		protocol.ConnectPacket {
			type = .CONNECT,
			QoS = .ExactlyOnce,
			Duplicate = false,
			Retain = false,
			UserName = "test",
		},
	)

	v := buf[:]
	util.print(v)
	util.sendTest(v)
}
