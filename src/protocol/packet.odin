package protocol

Packet_Type :: enum uint {
	Reserved    = 0,
	CONNECT     = 1,
	CONNACK     = 2,
	PUBLISH     = 3,
	PUBACK      = 4,
	PUBREC      = 5,
	PUBREL      = 6,
	PUBCOMP     = 7,
	SUBSCRIBE   = 8,
	SUBACK      = 9,
	UNSUBSCRIBE = 10,
	UNSUBACK    = 11,
	PINGREQ     = 12,
	PINGRESP    = 13,
	DISCONNECT  = 14,
	AUTH        = 15,
}

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

Property_Type :: enum {
	Byte,
	Two_Byte_Int,
	Four_Byte_Int,
	Var_Byte_Int,
	UTF8_String,
	Binary_Data,
	UTF8_String_Pair,
}

QoS_Type :: enum {
	At_Most_Once  = 0, // Fire and Forget
	At_Least_Once = 1, // PUBACK
	Exactly_Once  = 2, // PUBLISH, PUBREC, PUBREL, PUBCOMP
}

Will :: struct {
	topic:   string,
	message: []byte,
	qos:     QoS_Type,
	retain:  bool,
}

UserProperty :: struct {
	name:  string,
	value: string,
}

Properties :: struct {
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


Connect_Packet :: struct {
	duplicate:   bool,
	payload:     []byte,
	username:    Maybe(string),
	password:    Maybe([]byte),
	will:        Maybe(Will),
	clean_start: bool,
	keep_alive:  u16,
	properties:  Properties,
}

Packet :: union {
	Connect_Packet,
}
