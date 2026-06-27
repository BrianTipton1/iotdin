package protocol

import "core:encoding/varint"
import "core:fmt"
import "core:slice"
import "core:strings"
import "iotdin:util"

@(private)
FIXED_HEADER_FLAGS :: 0

Connect_Flags :: enum {
	Reserved,
	Clean_Start,
	Will_Flag,
	Will_QOS,
	Will_QOS2,
	Will_Retain,
	Password,
	User_Name,
}

Connect_Flags_Set :: bit_set[Connect_Flags]

Connect_Properties :: struct {
	session_expiry_interval:      u32,
	receive_maximum:              u16,
	maximum_packet_size:          u32,
	topic_alias_maximum:          u16,
	request_response_information: bool,
	request_problem_information:  bool,
	user_properties:              Maybe([]UserProperty),
	authentication_method:        Maybe(string), // TODO: come back to with better defined auth ideas
	authentication_data:          Maybe([]byte),
}

Connect_Will :: struct {
	qos:        QoS_Type,
	will_topic: string,
	payload:    string,
	properties: Maybe(Connect_Will_Properties),
	retain:     bool,
}

Connect_Will_Properties :: struct {
	will_delay_interval:      Maybe(u32),
	payload_format_indicator: Maybe(bool),
	message_expiry_interval:  Maybe(u32),
	content_type:             Maybe(string),
	response_topic:           Maybe(string),
	coorelation_data:         Maybe([]byte),
	user_properties:          Maybe([]UserProperty),
}


Connect_Packet :: struct {
	duplicate:         bool,
	username:          Maybe(string),
	password:          Maybe([]byte),
	clean_start:       bool,
	keep_alive:        u16,
	properties:        Connect_Properties,
	client_identifier: string,
	will:              Maybe(Connect_Will),
	protocol_version:  int,
	protocol:          string,
}


serialize_connect_properties :: proc(
	packet: Connect_Packet,
) -> (
	properties: [dynamic]byte,
	error: Serialize_Error,
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

	user_properties, user_properties_exist := packet.properties.user_properties.?
	if user_properties_exist {
		for user_property in user_properties {
			append_property(
				&properties_just_data,
				.User_Property,
				user_property.name,
				user_property.value,
			)
		}
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


	properties_len, properties_len_okay := make_u28(combined_byte_length)
	if !properties_len_okay {
		return properties, .Properties_Bigger_Than_U28
	}
	append_varint(&properties, properties_len)
	append(&properties, ..properties_just_data[:])


	return
}

// MQTT 5.0 Ref https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901035
connect_variable_header_first_ten :: proc(packet: Connect_Packet) -> (variableHeader: [10]byte) {
	bytes := [10]byte {
		byte(0),
		byte(4),
		byte('M'),
		byte('Q'),
		byte('T'),
		byte('T'),
		MQTT_VERSION,
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
	flags |= (1 << 5) if will_exists && will.retain else 0

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

serialize_connect_payload_will :: proc(
	will: Connect_Will,
) -> (
	will_payload_bytes: [dynamic]byte,
	error: Serialize_Error,
) {
	will_payload_bytes = make([dynamic]byte)

	properties, _ := will.properties.?

	will_properties_bytes := make([dynamic]byte)
	defer delete(will_properties_bytes)

	will_delay_interval, will_delay_interval_exists := properties.will_delay_interval.?
	if will_delay_interval_exists {
		append_property(&will_properties_bytes, .Will_Delay_Interval, will_delay_interval)
	}

	payload_format_indicator, payload_format_indicator_exists := properties.payload_format_indicator.?
	if payload_format_indicator_exists {
		append_property(
			&will_properties_bytes,
			.Payload_Format_Indicator,
			payload_format_indicator,
		)
	}

	message_expiry_interval, message_expiry_interval_exists := properties.message_expiry_interval.?
	if message_expiry_interval_exists {
		append_property(&will_properties_bytes, .Message_Expiry_Interval, message_expiry_interval)
	}

	content_type, content_type_exists := properties.content_type.?
	if content_type_exists {
		append_property(&will_properties_bytes, .Content_Type, content_type)
	}

	response_topic, response_topic_exists := properties.response_topic.?
	if response_topic_exists {
		append_property(&will_properties_bytes, .Response_Topic, response_topic)
	}

	c_data, c_data_exists := properties.coorelation_data.?
	if c_data_exists {
		append_property(&will_properties_bytes, .Correlation_Data, c_data)
	}

	user_props, user_props_exists := properties.user_properties.?
	if user_props_exists {
		for up in user_props {
			append_property(&will_properties_bytes, .User_Property, up.name, up.value)
		}
	}

	len_will_properties, len_will_properties_ok := make_u28(len(will_properties_bytes))
	if !len_will_properties_ok {
		return will_payload_bytes, .Will_Properties_Bigger_Than_U28
	}

	append_varint(&will_payload_bytes, len_will_properties)
	append(&will_payload_bytes, ..will_properties_bytes[:])
	append_string(&will_payload_bytes, will.will_topic)
	append_string(&will_payload_bytes, will.payload)
	return
}


serialize_connect_payload :: proc(
	packet: Connect_Packet,
) -> (
	payload_bytes: [dynamic]byte,
	error: Serialize_Error,
) {
	payload_bytes = make([dynamic]byte)
	append_string(&payload_bytes, packet.client_identifier)

	if will, will_exists := packet.will.?; will_exists {
		will_payload_bytes := serialize_connect_payload_will(will) or_return
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

	payload := serialize_connect_payload(packet) or_return
	defer delete(payload)

	size_of_packet, size_of_packet_ok := make_u28(
		len(variable_header_first_ten) + len(properties) + len(payload),
	)
	if !size_of_packet_ok {
		return .Packet_Size_Bigger_Than_U28
	}

	combined_size, combined_var_int := encode_variable_int(size_of_packet)
	serialize_fixed_header(buf, .CONNECT, combined_var_int[:combined_size], FIXED_HEADER_FLAGS)
	append(buf, ..variable_header_first_ten[:])
	append(buf, ..properties[:])
	append(buf, ..payload[:])

	return Serialize_Error.None
}


deserialize_connect_variable_header_flags :: proc(
	buf: []byte,
	offset: u16,
	packet: ^Connect_Packet,
) -> (
	error: DeSerialize_Error,
) {
	if len(buf) < cast(int)(offset + 2) {
		return .MQTT_Connect_Flags_Missing
	}
	connect_flags_byte := buf[offset + 1:offset + 2][0]
	flags := transmute(Connect_Flags_Set)connect_flags_byte

	will_flag := .Will_Flag in flags
	will_qos_one := .Will_QOS in flags
	will_qos_two := .Will_QOS2 in flags
	will_retain := .Will_Retain in flags
	if !will_flag && (will_qos_one || will_qos_two) {
		return .MQTT_Will_Flag_Unset_With_QOS
	}
	if !will_flag && will_retain {
		return .MQTT_Will_Flag_Unset_With_Retain
	}
	if will_flag {
		packet.will = Connect_Will {
			retain = will_retain,
			qos    = cast(QoS_Type)(int(will_qos_one) | int(will_qos_two) << 1),
		}
	}

	for flag in flags {
		#partial switch flag {
		case .Reserved:
			return .MQTT_Reserved_Flag_Set
		case .Clean_Start:
			packet.clean_start = true
		case .Password:
			packet.password = []byte{}
		case .User_Name:
			packet.username = ""
		}
	}

	return
}

deserialize_connect_variable_header_protocol :: proc(
	buf: []byte,
	offset: u16,
	packet: ^Connect_Packet,
) -> (
	err: DeSerialize_Error,
) {
	if len(buf) < cast(int)(offset) {
		return .MQTT_Protocol_Missing
	}

	protocol_message := buf[2:offset]
	protocol_str_builder: strings.Builder
	strings.builder_init(&protocol_str_builder)
	for b, i in protocol_message {
		strings.write_rune(&protocol_str_builder, rune(b))
	}
	packet.protocol = strings.to_string(protocol_str_builder)
	if packet.protocol != PROTOCOL_STR {
		err = .MQTT_Protocol_Malformed
	}

	return
}

deserialize_connect_variable_header_protocol_version :: proc(
	buf: []byte,
	offset: u16,
	packet: ^Connect_Packet,
) -> (
	err: DeSerialize_Error,
) {
	if len(buf) < cast(int)(offset + 1) {
		err = .MQTT_Protocol_Version_Missing
		return
	}

	protocol_version := buf[offset:offset + 1][0]
	if protocol_version != MQTT_VERSION {
		err = .MQTT_Protocol_Version_Malformed
	}

	return
}

deserialize_connect_variable_header_first_ten :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	err: DeSerialize_Error,
) {
	n_bytes := read_two_byte_slice(buf) or_return
	offset := n_bytes + 2

	deserialize_connect_variable_header_protocol(buf, offset, packet) or_return
	deserialize_connect_variable_header_protocol_version(buf, offset, packet) or_return
	deserialize_connect_variable_header_flags(buf, offset, packet) or_return

	return
}
