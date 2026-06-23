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

QoS_Type :: enum {
	AtMostOnce  = 0, // Fire and Forget
	AtLeastOnce = 1, // PUBACK
	ExactlyOnce = 2, // PUBLISH, PUBREC, PUBREL, PUBCOMP
}

Will :: struct {
	topic:   string,
	message: []byte,
	qos:     QoS_Type,
	retain:  bool,
}

Connect_Packet :: struct {
	duplicate:   bool,
	payload:     []byte,
	username:    Maybe(string),
	password:    Maybe([]byte),
	will:        Maybe(Will),
	clean_start: bool,
	keep_alive:  u16,
}

Packet :: union {
	Connect_Packet,
}
