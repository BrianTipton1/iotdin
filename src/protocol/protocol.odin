
package protocol

MQTT_VERSION :: 5

MQTT_Var_Int :: u32

serialize :: proc(buf: ^[dynamic]byte, packet: Packet) -> (error: MQTT_Error) {
	switch pkt in packet {
	case Connect_Packet:
		return serialize_connect_packet(buf, pkt)
	}

	return
}
