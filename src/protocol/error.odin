package protocol

MQTT_No_Error :: enum {
	None,
}

Serialize_Error :: enum {
	None,
	Binary_Data_Too_Long,
	Properties_Bigger_Than_U28,
	Will_Properties_Bigger_Than_U28,
	Packet_Size_Bigger_Than_U28,
}

De_Serialize_Error :: enum {
	None,
	MQTT_Protocol_Malformed,
	MQTT_Protocol_Missing,
	Two_Byte_Integer_Incorrect_Size,
	Two_Byte_Integer_Malformed_Size,
	MQTT_Protocol_Version_Missing,
	MQTT_Protocol_Version_Malformed,
	MQTT_Connect_Flags_Missing,
	MQTT_Reserved_Flag_Set,
	MQTT_Will_Flag_Unset_With_QOS,
	MQTT_Will_Flag_Unset_With_Retain,
	MQTT_Keep_Alive_Missing
}

MQTT_Error :: union {
	Serialize_Error,
	De_Serialize_Error,
	MQTT_No_Error,
}
