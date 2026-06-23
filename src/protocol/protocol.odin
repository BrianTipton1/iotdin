
package protocol

MQTT_VERSION :: 5

serialize :: proc(buf: ^[dynamic]byte, packet: Packet) -> (serializedPacket: ^[dynamic]byte) {
	switch pkt in packet {
	case Connect_Packet:
		return serialize_connect_packet(buf, pkt)
	}

	return
}
