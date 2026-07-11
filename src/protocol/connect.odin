package protocol

import "core:encoding/endian"
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
	user_properties:              Maybe(^[dynamic]UserProperty),
	authentication_method:        Maybe(string), // TODO: come back to with better defined auth ideas
	authentication_data:          Maybe([]byte),
}

Connect_Will :: struct {
	qos:        QoS_Type,
	will_topic: string,
	payload:    []byte,
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
	will:              Maybe(^Connect_Will),
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
serialize_connect_variable_header_first_ten :: proc(
	packet: Connect_Packet,
) -> (
	variableHeader: [10]byte,
) {
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
	append_binary(&will_payload_bytes, will.payload)
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
		will_payload_bytes := serialize_connect_payload_will(will^) or_return
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


serialize_connect_packet :: proc(
	buf: ^[dynamic]byte,
	packet: Connect_Packet,
) -> (
	error: Serialize_Error,
) {
	variable_header_first_ten := serialize_connect_variable_header_first_ten(packet)

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
	error: De_Serialize_Error,
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
	will := new(Connect_Will)
	will^ = Connect_Will {
		retain = will_retain,
		qos    = cast(QoS_Type)(int(will_qos_one) | int(will_qos_two) << 1),
	}

	if will_flag {
		packet.will = will}

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
	packet: ^Connect_Packet,
) -> (
	offset: u16,
	err: De_Serialize_Error,
) {
	protocol_n_bytes := read_two_byte_slice(buf) or_return
	offset = protocol_n_bytes + 2

	if len(buf) < cast(int)(offset) {
		err = .MQTT_Protocol_Missing
		return
	}

	protocol_message := buf[2:offset]
	protocol_str_builder: strings.Builder
	strings.builder_init(&protocol_str_builder)
	defer strings.builder_destroy(&protocol_str_builder)

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
	err: De_Serialize_Error,
) {
	if len(buf) < cast(int)(offset + 1) {
		err = .MQTT_Protocol_Version_Missing
		return
	}

	protocol_version := buf[offset:offset + 1][0]
	if protocol_version != MQTT_VERSION {
		err = .MQTT_Protocol_Version_Malformed
	}
	packet.protocol_version = int(protocol_version)

	return
}

deserialize_connect_variable_keep_alive :: proc(
	buf: []byte,
	offset: u16,
	packet: ^Connect_Packet,
) -> (
	err: De_Serialize_Error,
) {
	if len(buf) < cast(int)(offset + 4) {
		return .MQTT_Keep_Alive_Missing
	}

	keep_alive_bytes := buf[offset + 2:offset + 4]
	keep_alive := read_two_byte_slice(keep_alive_bytes) or_return

	packet.keep_alive = keep_alive

	return
}

deserialize_connect_variable_header_first_ten :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 10,
	err: De_Serialize_Error,
) {
	offset := deserialize_connect_variable_header_protocol(buf, packet) or_return
	deserialize_connect_variable_header_protocol_version(buf, offset, packet) or_return
	deserialize_connect_variable_header_flags(buf, offset, packet) or_return
	deserialize_connect_variable_keep_alive(buf, offset, packet) or_return

	return
}

deserialize_session_expirty_interval :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 4,
	error: De_Serialize_Error,
) {
	session_expiry, session_expiry_ok := endian.get_u32(buf, .Big)
	if !session_expiry_ok {
		error = .MQTT_Session_Expiry_Malformed
		return
	}
	packet.properties.session_expiry_interval = session_expiry
	return
}

deserialize_recv_max :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 2,
	error: De_Serialize_Error,
) {
	recv_max, recv_max_ok := endian.get_u16(buf, .Big)
	if !recv_max_ok {
		error = .MQTT_Recieve_Max_Malformed
		return
	}
	packet.properties.receive_maximum = recv_max

	return
}

deserialize_topic_alias_max :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 2,
	error: De_Serialize_Error,
) {
	topic_alias_max, topic_alias_max_ok := endian.get_u16(buf, .Big)
	if !topic_alias_max_ok {
		error = .MQTT_Topic_Alias_Max_Malformed
		return
	}
	packet.properties.topic_alias_maximum = topic_alias_max

	return
}

deserialize_maximum_packet_size :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 4,
	error: De_Serialize_Error,
) {
	maximum_packet_size, maximum_packet_size_okay := endian.get_u32(buf, .Big)
	if !maximum_packet_size_okay {
		error = .MQTT_Maximum_Packet_Size_Malformed
		return
	}
	packet.properties.maximum_packet_size = maximum_packet_size
	return
}

deserialize_request_response_info :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 1,
	error: De_Serialize_Error,
) {
	if len(buf) <= 1 {
		error = .MQTT_Request_Response_Info_Malformed
		return
	}
	b := buf[0]
	i := int(b)
	if i != 1 && i != 0 {
		error = .MQTT_Request_Response_Info_Malformed
		return
	}
	packet.properties.request_response_information = bool(b)
	return
}

deserialize_request_problem_info :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 1,
	error: De_Serialize_Error,
) {
	if len(buf) <= 1 {
		error = .MQTT_Request_Problem_Info_Malformed
		return
	}
	b := buf[0]
	i := int(b)
	if i != 1 && i != 0 {
		error = .MQTT_Request_Problem_Info_Malformed
		return
	}
	packet.properties.request_response_information = bool(b)
	return
}

deserialize_request_user_property :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	name_size, name_size_ok := endian.get_u16(buf, .Big)
	if !name_size_ok {
		error = .MQTT_Deserialize_User_Property_Name_Length_Failed
		return
	}
	name_bytes := buf[2:name_size + 2]
	name := string(name_bytes)
	remove_name := buf[2 + name_size:]

	value_size, value_size_ok := endian.get_u16(remove_name, .Big)
	if !value_size_ok {
		error = .MQTT_Deserialize_User_Property_Value_Length_Failed
	}


	value_bytes := remove_name[2:value_size + 2]
	value := string(value_bytes)

	existing_user_props, user_props_exist := packet.properties.user_properties.?

	new_property := UserProperty {
		name  = name,
		value = value,
	}

	if user_props_exist {
		append(existing_user_props, new_property)
	} else {
		new_user_properties := new([dynamic]UserProperty)
		append(new_user_properties, new_property)
		packet.properties.user_properties = new_user_properties
	}

	len_read = int(4 + name_size + value_size)

	return
}

deserialize_authentication_method :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	size, size_ok := endian.get_u16(buf, .Big)
	if !size_ok {

	}
	packet.properties.authentication_method = string(buf[2:size])

	len_read = int(size + 2)
	return
}

deserialize_authentication_data :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	size, size_ok := endian.get_u16(buf, .Big)
	if !size_ok {

	}
	packet.properties.authentication_data = buf[2:size]

	len_read = int(size + 2)
	return
}


deserialize_property_by_id :: proc(
	property_id: Property_ID,
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	#partial switch property_id {
	case .Session_Expiry_Interval:
		return deserialize_session_expirty_interval(buf, packet)
	case .Receive_Maximum:
		return deserialize_recv_max(buf, packet)
	case .Maximum_Packet_Size:
		return deserialize_maximum_packet_size(buf, packet)
	case .Topic_Alias_Maximum:
		return deserialize_topic_alias_max(buf, packet)
	case .Request_Response_Information:
		return deserialize_request_response_info(buf, packet)
	case .Request_Problem_Information:
		return deserialize_request_problem_info(buf, packet)
	case .User_Property:
		return deserialize_request_user_property(buf, packet)
	case .Authentication_Method:
		return deserialize_authentication_method(buf, packet)
	case .Authentication_Data:
		return deserialize_authentication_data(buf, packet)
	}
	return
}

deserialize_connect_properties :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	offset: int,
	err: De_Serialize_Error,
) {
	var_int, len_ok := decode_var_int(buf)
	len_props := var_int.u28.value
	size := var_int.size

	if !len_ok {
		err = .MQTT_Connect_Property_Var_Int_Incorrect_Size
		return
	}
	properties_bytes := buf[size:len_props + 1]

	offset = size + int(len_props)

	len_read := 0
	i := 0
	for {
		offset := len_read + i
		if offset >= len(properties_bytes) {
			break
		}
		b := properties_bytes[offset]
		property_id := transmute(Property_ID)b
		len_read += deserialize_property_by_id(
			property_id,
			properties_bytes[1 + offset:],
			packet,
		) or_return
		i += 1
	}

	return
}

deserialize_connect_client_identifier :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	packet.client_identifier, len_read = deserialize_utf8_string(
		buf,
		.MQTT_Deserialize_Client_Identifier_Length_Failed,
		.MQTT_Deserialize_Client_Identifier_Malformed,
	) or_return

	return
}


deserialize_will_properties :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	will, will_flag := packet.will.?
	if !will_flag {
		return
	}
	// Swap to a deserialize_T_properties proc that takes in a given set of appropriate properties.
	len_read = deserialize_connect_properties(buf, packet) or_return
	return
}

deserialize_will_topic :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	will, will_flag := packet.will.?
	if !will_flag {
		return
	}

	will.will_topic, len_read = deserialize_utf8_string(
		buf,
		.MQTT_Deserialize_Will_Topic_Length_Failed,
		.MQTT_Deserialize_Will_Topic_Malformed,
	) or_return

	return
}

deserialize_will_payload :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int,
	error: De_Serialize_Error,
) {
	will, will_flag := packet.will.?
	if !will_flag {
		return
	}
	len_will_payload, len_will_payload_okay := endian.get_u16(buf, .Big)
	if !len_will_payload_okay {
		error = .MQTT_Deserialize_Will_Payload_Length_Failed
		return
	}

	will_payload := buf[2:len_will_payload]
	will.payload = will_payload

	len_read = int(len_will_payload) + 2

	return
}

deserialize_connect_user_name :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 2,
	error: De_Serialize_Error,
) {
	if _, user_name_flag := packet.username.?; !user_name_flag {
		return
	}
	user_name_len, user_name_len_okay := endian.get_u16(buf, .Big)
	if !user_name_len_okay {
		error = .MQTT_Deserialize_User_Name_Length_Failed
		return
	}
	user_name := buf[2:user_name_len]

	packet.username = string(user_name)

	len_read += int(user_name_len)

	return
}

deserialize_connect_password :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	len_read: int = 2,
	error: De_Serialize_Error,
) {
	if _, password_flag := packet.username.?; !password_flag {
		return
	}
	password_len, password_len_okay := endian.get_u16(buf, .Big)
	if !password_len_okay {
		error = .MQTT_Deserialize_Password_Length_Failed
		return
	}
	password := buf[2:password_len]

	packet.password = password

	len_read += int(password_len)

	return
}

deserialize_connect_payload :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	error: De_Serialize_Error,
) {
	read := deserialize_connect_client_identifier(buf, packet) or_return
	read += deserialize_will_properties(buf[read:], packet) or_return
	read += deserialize_will_topic(buf[read:], packet) or_return
	read += deserialize_will_payload(buf[read:], packet) or_return
	read += deserialize_connect_user_name(buf[read:], packet) or_return
	read += deserialize_connect_password(buf[read:], packet) or_return

	return .None
}

deserialize_connect_packet :: proc(
	buf: []byte,
	packet: ^Connect_Packet,
) -> (
	error: De_Serialize_Error,
) {
	var_byte := buf[1:5]
	var_int, remaing_length_ok := decode_var_int(var_byte)
	if !remaing_length_ok {
		return .MQTT_Connect_Deserialize_Remaining_Length_Failed

	}
	read := var_int.size + 1
	read += deserialize_connect_variable_header_first_ten(buf[read:], packet) or_return
	read += deserialize_connect_properties(buf[read:], packet) or_return
	deserialize_connect_payload(buf[read:], packet) or_return

	return
}
