
package protocol

MQTT_VERSION :: byte(5)
PROTOCOL_STR :: "MQTT"
U28_MAX :: u32(1 << 28) - 1


serialize :: proc(buf: ^[dynamic]byte, packet: Packet) -> (error: MQTT_Error) {
	switch pkt in packet {
	case Connect_Packet:
		return serialize_connect_packet(buf, pkt)
	}

	return
}
