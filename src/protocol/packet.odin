package protocol

import "core:math/bits"
import "core:slice"

PacketType :: enum uint {
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

ConnectPacket :: struct {
	type:       PacketType,
	QoS:        Maybe(QoSType),
	Retain:     bool,
	Duplicate:  bool,
	Payload:    []byte,
	UserName:   Maybe(string),
	Password:   Maybe(string),
	WillFlag:   bool,
	CleanStart: bool,
	KeepAlive:  int,
}

Packet :: union {
	ConnectPacket,
}

flagsFromPacket :: proc(packet: ConnectPacket) -> (flags: int) {
	#partial switch packet.type {
	case .CONNECT:
		flags = 0
	case .CONNACK:
		flags = 0
	case .PUBLISH:
		flags |= (1 << 0) if packet.Retain else 0
		flags |= (1 << 1) if packet.QoS == .AtLeastOnce else 0
		flags |= (1 << 2) if packet.QoS == .ExactlyOnce else 0
		flags |= (1 << 3) if packet.Duplicate else 0
	case .PUBACK:
		flags = 0
	case .PUBREC:
		flags = 0
	case .PUBREL:
		flags |= (1 << 1)
	case .PUBCOMP:
		flags = 0
	case .SUBSCRIBE:
		flags |= (1 << 1)
	case .SUBACK:
		flags = 0
	case .UNSUBSCRIBE:
		flags |= (1 << 1)
	case .UNSUBACK:
		flags = 0
	case .PINGREQ:
	case .PINGRESP:
		flags = 0
	case .DISCONNECT:
		flags = 0
	case .AUTH:
		flags = 0
	}

	return
}

controlHeaderByte :: proc(packetType: PacketType, flags: int) -> (controlHeader: byte) {
	enumValue := cast(int)packetType

	b := bits.bitfield_insert(0, enumValue, 4, 4)
	b = bits.bitfield_insert(b, flags, 0, 4)

	controlHeader = byte(b)
	return
}

fixedHeader :: proc(
	buf: ^[dynamic]byte,
	packet: ConnectPacket,
	variableHeaderLength: int,
	flags: int,
) {
	controlHeader := controlHeaderByte(packet.type, flags)
	remainingLength := variableHeaderLength + len(packet.Payload)
	fixedHeader := []byte{controlHeader, byte(remainingLength)}
	append(buf, ..fixedHeader)
}
