package main

import "core:fmt"
import "iotdin:protocol"
import "iotdin:transport"
import "util"


main :: proc() {
	fmt.println()

	buf := make([dynamic]byte)
	defer delete(buf)
	x := protocol.serialize(
		&buf,
		protocol.Connect_Packet {
			will = protocol.Will{qos = .AtMostOnce},
			duplicate = false,
			username = "test",
			password = []byte{byte('P'), byte('A'), byte('S'), byte('S')},
		},
	)

	v := buf[:]
	util.print(v)
	transport.sendTest(v)
}
