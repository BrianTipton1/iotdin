package protocol
import "../util"
import "core:fmt"
import "core:os"
import "core:slice"


@(private)
FIXED_HEADER_FLAGS :: 0

// MQTT 5.0 Ref https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901035
connectVariableHeader :: proc(packet: ConnectPacket) -> (variableHeader: [dynamic]byte) {
	constBytes := []byte {
		byte(0), // Len MSB
		byte(4), // Len LSB
		'M',
		'Q',
		'T',
		'T',
		byte(MQTT_VERSION), // Protocol Version
	}

	buf := make([dynamic]byte)

	append(&buf, ..constBytes)
	connectFlags := connectFlags(packet)
	append(&buf, connectFlags)
	append(&buf, byte(packet.KeepAlive))
	append(&buf, byte(packet.KeepAlive))

	return buf
}


// https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html#_Toc3901038
connectFlags :: proc(packet: ConnectPacket) -> (flags: byte) {
	flags |= (1 << 7) if packet.UserName != nil else 0
	flags |= (1 << 6) if packet.Password != nil else 0
	flags |= (1 << 5) if packet.WillFlag else 0

	if packet.WillFlag {
		switch packet.QoS {
		case QoSType.AtMostOnce:
			break
		case QoSType.AtLeastOnce:
			flags |= (1 << 3)
		case QoSType.ExactlyOnce:
			flags |= (1 << 4)
		}
	}

	flags |= (1 << 2) if packet.WillFlag else 0
	flags |= (1 << 1) if packet.CleanStart else 0

	return
}


serializeConnectPacket :: proc(
	buf: ^[dynamic]byte,
	packet: ConnectPacket,
) -> (
	serializedPacket: ^[dynamic]byte,
) {
	variableHeader := connectVariableHeader(packet)
	defer delete(variableHeader)
	fixedHeader(buf, packet, len(variableHeader), FIXED_HEADER_FLAGS)
	append(buf, ..variableHeader[:])

	return buf
}
