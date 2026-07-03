
package protocol

MQTT_VERSION :: byte(5)
PROTOCOL_STR :: "MQTT"
U28_MAX :: u32(1 << 28) - 1


serialize :: proc(buf: ^[dynamic]byte, packet: Packet) -> (error: MQTT_Error) {
	switch pkt in packet {
	case Connect_Packet:
		serialize_connect_packet(buf, pkt) or_return
	}

	return
}


deserialize :: proc(buf: []byte) -> (packet: ^Packet, error: MQTT_Error) {
	packet = make_packet(buf)

	switch &p in packet {
	case Connect_Packet:
		deserialize_connect_packet(buf, &p) or_return
	}

	return
}
