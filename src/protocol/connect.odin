package protocol

import "core:fmt"
import "iotdin:util"

@(private)
FIXED_HEADER_FLAGS :: 0

// MQTT 5.0 Ref https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901035
connect_variable_header_first_ten :: proc(packet: Connect_Packet) -> (variableHeader: [10]byte) {
	bytes := [10]byte {
		byte(0), // Len MSB
		byte(4), // Len LSB
		byte('M'),
		byte('Q'),
		byte('T'),
		byte('T'),
		byte(MQTT_VERSION), // Protocol Version
		connect_variable_flags(packet),
		byte(packet.keep_alive >> 8),
		byte(packet.keep_alive),
	}

	return bytes
}


// https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901038
connect_variable_flags :: proc(packet: Connect_Packet) -> (flags: byte) {
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
	error: Serialize_Connect_Error,
) {
	variable_header := connect_variable_header_first_ten(packet)
	size, err, var_int := encode_variable_int(
		cast(u128)(len(packet.payload) + len(variable_header)),
	)

	fixedHeader(buf, .CONNECT, var_int[:size], FIXED_HEADER_FLAGS)
	append(buf, ..variable_header[:])

	return .None
}
