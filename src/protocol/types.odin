package protocol

U28 :: bit_field u32 {
	value: u32 | 28,
}
Var_Int :: struct {
	u28:  U28,
	size: int,
}

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
	At_Most_Once  = 0, // Fire and Forget
	At_Least_Once = 1, // PUBACK
	Exactly_Once  = 2, // PUBLISH, PUBREC, PUBREL, PUBCOMP
}

Packet :: union {
	Connect_Packet,
}
