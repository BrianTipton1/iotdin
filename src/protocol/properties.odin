#+feature dynamic-literals

package protocol

import "base:intrinsics"

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

append_scalar_property :: proc(
	buf: ^[dynamic]byte,
	id: Property_ID,
	value: $T,
) -> MQTT_Error where intrinsics.type_is_integer(T) {
	append(buf, byte(id))
	return append_scalar(buf, value)
}

append_bool_property :: proc(buf: ^[dynamic]byte, id: Property_ID, value: bool) -> MQTT_Error {
	append(buf, byte(id))
	append_bool(buf, value)
	return MQTT_No_Error.None
}


append_string_property :: proc(buf: ^[dynamic]byte, id: Property_ID, s: string) -> MQTT_Error {
	append(buf, byte(id))
	append_string(buf, s)
	return MQTT_No_Error.None
}

append_binary_property :: proc(buf: ^[dynamic]byte, id: Property_ID, data: []byte) -> MQTT_Error {
	append(buf, byte(id))
	return append_binary(buf, data)
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

append_varint_property :: proc(buf: ^[dynamic]byte, id: Property_ID, value: U28) -> MQTT_Error {
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


Properties :: union {
	Connect_Properties,
	Connect_Will_Properties,
}
