package protocol

import "core:encoding/varint"
import "core:fmt"
import "iotdin:util"

@(private)
FIXED_HEADER_FLAGS :: 0


connect_properties :: proc(
	packet: Connect_Packet,
) -> (
	properties: [dynamic]byte,
	error: varint.Error,
) {
	properties = make([dynamic]byte)

	session_expiry_start := byte(Property_ID.Session_Expiry_Interval)
	session_expiry := transmute([4]byte)(u32be)(packet.properties.session_expiry_interval)

	receive_maximum_start := byte(Property_ID.Receive_Maximum)
	receive_maximum := transmute([2]byte)(u16be)(packet.properties.receive_maximum)

	maximum_packet_size_start := byte(Property_ID.Maximum_Packet_Size)
	maximum_packet_size := transmute([4]byte)(u32be)(packet.properties.maximum_packet_size)

	topic_alias_maximum_start := byte(Property_ID.Topic_Alias_Maximum)
	topic_alias_maximum := transmute([2]byte)(u16be)(packet.properties.topic_alias_maximum)

	request_response_information_start := byte(Property_ID.Request_Response_Information)
	request_response_information :=
		byte(1) if packet.properties.request_response_information else byte(0)

	request_problem_information_start := byte(Property_ID.Request_Problem_Information)
	request_problem_information :=
		byte(1) if packet.properties.request_problem_information else byte(0)

	user_properties := make([dynamic]byte)
	defer delete(user_properties)
	for user_property in packet.properties.user_properties {
		append(&user_properties, byte(Property_ID.User_Property))

		name_bytes := transmute([]byte)(user_property.name)
		name_len := byte(len(name_bytes))
		append(&user_properties, name_len)
		append(&user_properties, ..name_bytes)

		value_bytes := transmute([]byte)(user_property.name)
		value_len := byte(len(value_bytes))
		append(&user_properties, value_len)
		append(&user_properties, ..value_bytes)
	}
	user_properties_len := len(user_properties)

	combined_byte_length :=
		(1 + len(session_expiry)) +
		(1 + len(receive_maximum)) +
		(1 + len(maximum_packet_size)) +
		(1 + len(topic_alias_maximum)) +
		(1 + 1) +
		(1 + 1) +
		(user_properties_len)

	size: int
	var_int: [4]byte
	size, error, var_int = encode_variable_int(u128(combined_byte_length))
	if error != .None {
		return
	}

	append(&properties, ..var_int[:size])

	append(&properties, session_expiry_start)
	append(&properties, ..session_expiry[:])

	append(&properties, receive_maximum_start)
	append(&properties, ..receive_maximum[:])

	append(&properties, maximum_packet_size_start)
	append(&properties, ..maximum_packet_size[:])

	append(&properties, topic_alias_maximum_start)
	append(&properties, ..topic_alias_maximum[:])

	append(&properties, request_response_information_start)
	append(&properties, request_response_information)

	append(&properties, request_problem_information_start)
	append(&properties, request_problem_information)

	append(&properties, ..user_properties[:])

	return
}

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
		case .At_Most_Once:
			break
		case .At_Least_Once:
			flags |= (1 << 3)
		case .Exactly_Once:
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
	variable_header_first_ten := connect_variable_header_first_ten(packet)
	properties, e := connect_properties(packet)
	defer delete(properties)
	size, err, var_int := encode_variable_int(
		cast(u128)(len(packet.payload) + len(variable_header_first_ten) + len(properties)),
	)

	fixedHeader(buf, .CONNECT, var_int[:size], FIXED_HEADER_FLAGS)
	append(buf, ..variable_header_first_ten[:])
	append(buf, ..properties[:])

	return .None
}
