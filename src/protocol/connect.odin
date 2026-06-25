package protocol

import "core:encoding/varint"
import "core:fmt"
import "core:slice"
import "iotdin:util"

@(private)
FIXED_HEADER_FLAGS :: 0

connect_properties :: proc(
	packet: Connect_Packet,
) -> (
	len_var_int: [4]byte,
	len_var_int_size: int,
	properties: [dynamic]byte,
	error: varint.Error,
) {
	properties = make([dynamic]byte)

	append_property(
		&properties,
		.Session_Expiry_Interval,
		packet.properties.session_expiry_interval,
	)
	append_property(&properties, .Receive_Maximum, packet.properties.receive_maximum)
	append_property(&properties, .Maximum_Packet_Size, packet.properties.maximum_packet_size)
	append_property(&properties, .Topic_Alias_Maximum, packet.properties.topic_alias_maximum)
	append_property(
		&properties,
		.Request_Response_Information,
		packet.properties.request_response_information,
	)
	append_property(
		&properties,
		.Request_Problem_Information,
		packet.properties.request_problem_information,
	)

	for user_property in packet.properties.user_properties {
		append_property(&properties, .User_Property, user_property.name, user_property.value)
	}

	append_property(
		&properties,
		.Authentication_Method,
		packet.properties.authentication_method.(string),
	)
	append_property(
		&properties,
		.Authentication_Data,
		packet.properties.authentication_data.([]byte),
	)

	combined_byte_length := len(properties)

	len_var_int_size, error, len_var_int = encode_variable_int(u128(combined_byte_length))
	if error != .None {
		return
	}

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


connect_payload :: proc(payload: Connect_Payload) -> (payload_bytes: [dynamic]byte) {
	payload_bytes = make([dynamic]byte)

	append_property(&payload_bytes, .Assigned_Client_Identifier, payload.client_identifier)
	return
}


// TODO: Robust tests needed once decode in place
serialize_connect_packet :: proc(
	buf: ^[dynamic]byte,
	packet: Connect_Packet,
) -> (
	error: Serialize_Error,
) {
	variable_header_first_ten := connect_variable_header_first_ten(packet)
	properties_var_int_len, len_var_int_size, properties, e := connect_properties(packet)
	defer delete(properties)

	payload := connect_payload(packet.payload)
	defer delete(payload)

	combined_size, err, combined_var_int := encode_variable_int(
		cast(u128)(len(payload) +
			len(variable_header_first_ten) +
			len_var_int_size +
			len(properties)),
	)

	fixedHeader(buf, .CONNECT, combined_var_int[:combined_size], FIXED_HEADER_FLAGS)
	append(buf, ..variable_header_first_ten[:])
	append(buf, ..properties_var_int_len[:len_var_int_size])
	append(buf, ..properties[:])

	return .None
}
