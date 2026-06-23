package protocol

import "core:fmt"
import "iotdin:util"

@(private)
FIXED_HEADER_FLAGS :: 0

// MQTT 5.0 Ref https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901035
connectVariableHeader :: proc(packet: Connect_Packet) -> (variableHeader: [dynamic]byte) {
	constBytes := []byte {
		byte(0), // Len MSB
		byte(4), // Len LSB
		'M',
		'Q',
		'T',
		'T',
		byte(MQTT_VERSION), // Protocol Version
	}

	buf := make([dynamic]byte)

	append(&buf, ..constBytes)
	connectFlags := connectFlags(packet)
	append(&buf, connectFlags)
	append(&buf, byte(packet.keep_alive >> 8))
	append(&buf, byte(packet.keep_alive))

	return buf
}


// https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901038
connectFlags :: proc(packet: Connect_Packet) -> (flags: byte) {
	will, will_exists := packet.will.?

	flags |= (1 << 7) if packet.username != nil else 0
	flags |= (1 << 6) if packet.password != nil else 0
	flags |= (1 << 5) if will_exists else 0

	if will_exists {
		switch will.qos {
		case .AtMostOnce:
			break
		case .AtLeastOnce:
			flags |= (1 << 3)
		case .ExactlyOnce:
			flags |= (1 << 4)
		}
	}

	flags |= (1 << 2) if will_exists else 0
	flags |= (1 << 1) if packet.clean_start else 0

	return
}


serialize_connect_packet :: proc(
	buf: ^[dynamic]byte,
	packet: Connect_Packet,
) -> (
	serialized_packet: ^[dynamic]byte,
) {
	variableHeader := connectVariableHeader(packet)
	defer delete(variableHeader)

	var_int: [4]byte
	size, err := encode_variable_int(
		&var_int,
		cast(u128)(len(packet.payload) + len(variableHeader)),
	)


	compressed: [dynamic]byte
	for b in var_int {
		append(&compressed, b)
		flags := transmute(Variable_Byte_Bits)b
		if .Continuation not_in flags {
			break
		}
	}
	fixedHeader(buf, .CONNECT, compressed[:], FIXED_HEADER_FLAGS)
	append(buf, ..variableHeader[:])

	return buf
}
