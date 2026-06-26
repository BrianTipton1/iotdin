
package protocol

import "base:intrinsics"
import "core:encoding/varint"

MAX_TWO_BYTE_PREFIX_LEN :: 0xFFFF

Property_ID :: enum u8 {
	Payload_Format_Indicator          = 0x01,
	Message_Expiry_Interval           = 0x02,
	Content_Type                      = 0x03,
	Response_Topic                    = 0x08,
	Correlation_Data                  = 0x09,
	Subscription_Identifier           = 0x0B,
	Session_Expiry_Interval           = 0x11,
	Assigned_Client_Identifier        = 0x12,
	Server_Keep_Alive                 = 0x13,
	Authentication_Method             = 0x15,
	Authentication_Data               = 0x16,
	Request_Problem_Information       = 0x17,
	Will_Delay_Interval               = 0x18,
	Request_Response_Information      = 0x19,
	Response_Information              = 0x1A,
	Server_Reference                  = 0x1C,
	Reason_String                     = 0x1F,
	Receive_Maximum                   = 0x21,
	Topic_Alias_Maximum               = 0x22,
	Topic_Alias                       = 0x23,
	Maximum_QoS                       = 0x24,
	Retain_Available                  = 0x25,
	User_Property                     = 0x26,
	Maximum_Packet_Size               = 0x27,
	Wildcard_Subscription_Available   = 0x28,
	Subscription_Identifier_Available = 0x29,
	Shared_Subscription_Available     = 0x2A,
}

append_scalar :: proc(
	buf: ^[dynamic]byte,
	value: $T,
) -> MQTT_Error where intrinsics.type_is_integer(T) {
	when size_of(T) == 1 {
		append(buf, byte(value))
	} else when size_of(T) == 2 {
		b := transmute([2]byte)(u16be(value))
		append(buf, ..b[:])
	} else when size_of(T) == 4 {
		b := transmute([4]byte)(u32be(value))
		append(buf, ..b[:])
	} else {
		#panic("append_property: unsupported integer size")
	}
	return .None
}

append_scalar_property :: proc(
	buf: ^[dynamic]byte,
	id: Property_ID,
	value: $T,
) -> MQTT_Error where intrinsics.type_is_integer(T) {
	append(buf, byte(id))
	return append_scalar(buf, value)
}
append_bool :: proc(buf: ^[dynamic]byte, value: bool) -> MQTT_Error {
	append(buf, byte(1) if value else byte(0))
	return .None
}
append_bool_property :: proc(buf: ^[dynamic]byte, id: Property_ID, value: bool) -> MQTT_Error {
	append(buf, byte(id))
	append_bool(buf, value)
	return .None
}


append_string :: proc(buf: ^[dynamic]byte, s: string) -> MQTT_Error {
	length := transmute([2]byte)(u16be(len(s)))
	append(buf, ..length[:])
	append(buf, ..transmute([]byte)s)
	return .None
}

append_string_property :: proc(buf: ^[dynamic]byte, id: Property_ID, s: string) -> MQTT_Error {
	append(buf, byte(id))
	append_string(buf, s)
	return .None
}

append_binary :: proc(buf: ^[dynamic]byte, data: []byte) -> MQTT_Error {
	length := transmute([2]byte)(u16be(len(data)))
	append(buf, ..length[:])
	append(buf, ..data)
	return .None
}

append_binary_property :: proc(buf: ^[dynamic]byte, id: Property_ID, data: []byte) -> MQTT_Error {
	append(buf, byte(id))
	return append_binary(buf, data)
}

append_pair :: proc(buf: ^[dynamic]byte, name: string, value: string) -> MQTT_Error {
	name_len := transmute([2]byte)(u16be(len(name)))
	append(buf, ..name_len[:])
	append(buf, ..transmute([]byte)name)
	value_len := transmute([2]byte)(u16be(len(value)))
	append(buf, ..value_len[:])
	append(buf, ..transmute([]byte)value)
	return .None
}

append_pair_property :: proc(
	buf: ^[dynamic]byte,
	id: Property_ID,
	name: string,
	value: string,
) -> MQTT_Error {
	append(buf, byte(id))
	return append_pair(buf, name, value)
}

append_varint :: proc(buf: ^[dynamic]byte, value: u128) -> MQTT_Error {
	size, err, encoded := encode_variable_int(value)
	if err != .None do return MQTT_Var_Int_Error.Variable_Bytes_More_Than_Four
	append(buf, ..encoded[:size])
	return .None
}

append_varint_property :: proc(buf: ^[dynamic]byte, id: Property_ID, value: u128) -> MQTT_Error {
	append(buf, byte(id))
	return append_varint(buf, value)
}

// TODO: need better error handling around values that are sized incorrectly
append_property :: proc {
	append_scalar_property,
	append_bool_property,
	append_string_property,
	append_binary_property,
	append_pair_property,
	append_varint_property,
}

UserProperty :: struct {
	name:  string,
	value: string,
}

Connect_Properties :: struct {
	session_expiry_interval:      u32,
	receive_maximum:              u16,
	maximum_packet_size:          u32,
	topic_alias_maximum:          u16,
	request_response_information: bool,
	request_problem_information:  bool,
	user_properties:              []UserProperty,
	authentication_method:        Maybe(string), // TODO: come back to with better defined auth ideas
	authentication_data:          Maybe([]byte),
}

Connect_Will_Properties :: struct {
	will_delay_interval:      u32,
	payload_format_indicator: bool,
	message_expiry_interval:  u32,
	content_type:             string,
	response_topic:           string,
	coorelation_data:         Maybe([]byte),
	user_properties:          Maybe([]UserProperty),
	will_topic:               string,
}


Properties :: union {
	Connect_Properties,
	Connect_Will_Properties,
}
