package protocol

import "core:encoding/varint"
import "core:fmt"
import "core:slice"
import "iotdin:util"

@(private)
FIXED_HEADER_FLAGS :: 0

serialize_connect_properties :: proc(
	packet: Connect_Packet,
) -> (
	properties: [dynamic]byte,
	error: varint.Error,
) {
	properties = make([dynamic]byte)
	properties_just_data := make([dynamic]byte)
	defer delete(properties_just_data)

	append_property(
		&properties_just_data,
		.Session_Expiry_Interval,
		packet.properties.session_expiry_interval,
	)
	append_property(&properties_just_data, .Receive_Maximum, packet.properties.receive_maximum)
	append_property(
		&properties_just_data,
		.Maximum_Packet_Size,
		packet.properties.maximum_packet_size,
	)
	append_property(
		&properties_just_data,
		.Topic_Alias_Maximum,
		packet.properties.topic_alias_maximum,
	)
	append_property(
		&properties_just_data,
		.Request_Response_Information,
		packet.properties.request_response_information,
	)
	append_property(
		&properties_just_data,
		.Request_Problem_Information,
		packet.properties.request_problem_information,
	)

	for user_property in packet.properties.user_properties {
		append_property(
			&properties_just_data,
			.User_Property,
			user_property.name,
			user_property.value,
		)
	}

	if auth_method, auth_method_exists := packet.properties.authentication_method.?;
	   auth_method_exists {
		append_property(&properties_just_data, .Authentication_Method, auth_method)
	}
	if auth_data, auth_data_exists := packet.properties.authentication_data.?; auth_data_exists {
		append_property(
			&properties_just_data,
			.Authentication_Data,
			packet.properties.authentication_data.([]byte),
		)
	}

	combined_byte_length := len(properties_just_data)


	len_var_int: [4]byte
	len_var_int_size: int
	len_var_int_size, error, len_var_int = serialize_variable_int(u128(combined_byte_length))


	append(&properties, ..len_var_int[:len_var_int_size])
	append(&properties, ..properties_just_data[:])


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
	_, username_exists := packet.username.?
	flags |= (1 << 7) if username_exists else 0

	_, password_exists := packet.password.?
	flags |= (1 << 6) if password_exists else 0

	will, will_exists := packet.will.?
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

connect_payload_will :: proc(packet: Connect_Packet) -> (will_payload_bytes: [dynamic]byte) {
	will_properties_bytes := make([dynamic]byte)
	defer delete(will_properties_bytes)
	will_payload_bytes = make([dynamic]byte)
	append_property(
		&will_properties_bytes,
		.Will_Delay_Interval,
		packet.payload.will_properties.will_delay_interval,
	)
	append_property(
		&will_properties_bytes,
		.Payload_Format_Indicator,
		packet.payload.will_properties.payload_format_indicator,
	)
	append_property(
		&will_properties_bytes,
		.Message_Expiry_Interval,
		packet.payload.will_properties.message_expiry_interval,
	)

	append_property(
		&will_properties_bytes,
		.Content_Type,
		packet.payload.will_properties.content_type,
	)

	append_property(
		&will_properties_bytes,
		.Response_Topic,
		packet.payload.will_properties.response_topic,
	)
	if c_data, c_data_exists := packet.payload.will_properties.coorelation_data.?; c_data_exists {
		append_property(&will_properties_bytes, .Correlation_Data, c_data)
	}
	if user_props, user_props_exists := packet.payload.will_properties.user_properties.?;
	   user_props_exists {
		for up in user_props {
			append_property(&will_properties_bytes, .User_Property, up.name, up.value)
		}
	}

	len_will_properties := cast((u128))len(will_properties_bytes)
	append_varint(&will_payload_bytes, len_will_properties)
	append(&will_payload_bytes, ..will_properties_bytes[:])
	append_string(&will_payload_bytes, packet.payload.will_properties.will_topic)
	append_string(&will_payload_bytes, "Some test payload")
	return
}


serialize_connect_payload :: proc(packet: Connect_Packet) -> (payload_bytes: [dynamic]byte) {
	payload_bytes = make([dynamic]byte)
	append_string(&payload_bytes, packet.payload.client_identifier)

	if will, will_exists := packet.will.?; will_exists {
		will_payload_bytes := connect_payload_will(packet)
		defer delete(will_payload_bytes)
		append(&payload_bytes, ..will_payload_bytes[:])
	}

	if user_name, exists := packet.username.?; exists {
		append_string(&payload_bytes, user_name)
	}
	if password, exists := packet.password.?; exists {
		append_binary(&payload_bytes, password)
	}


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
	properties, e := serialize_connect_properties(packet)
	defer delete(properties)

	payload := serialize_connect_payload(packet)
	defer delete(payload)

	size_of_packet := cast(u128)(len(variable_header_first_ten) + len(properties) + len(payload))
	combined_size, err, combined_var_int := serialize_variable_int(size_of_packet)

	serialize_fixed_header(buf, .CONNECT, combined_var_int[:combined_size], FIXED_HEADER_FLAGS)
	append(buf, ..variable_header_first_ten[:])
	append(buf, ..properties[:])
	append(buf, ..payload[:])

	return .None
}
