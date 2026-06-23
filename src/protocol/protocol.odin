
package protocol

MQTT_VERSION :: 5

serialize :: proc(buf: ^[dynamic]byte, packet: ConnectPacket) -> (serializedPacket: ^[dynamic]byte) {
	#partial switch packet.type {
	case .CONNECT:
		return serializeConnectPacket(buf, packet)
	case .CONNACK:
	case .PUBLISH:
	case .PUBACK:
	case .PUBREC:
	case .PUBREL:
	case .PUBCOMP:
	case .SUBSCRIBE:
	case .SUBACK:
	case .UNSUBSCRIBE:
	case .UNSUBACK:
	case .PINGREQ:
	case .PINGRESP:
	case .DISCONNECT:
	case .AUTH:
	}

	return
}
