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
	MQTT_Keep_Alive_Missing,
	MQTT_Connect_Property_Var_Int_Incorrect_Size,
	MQTT_Session_Expiry_Malformed,
	MQTT_Recieve_Max_Malformed,
	MQTT_Topic_Alias_Max_Malformed,
	MQTT_Maximum_Packet_Size_Malformed,
	MQTT_Request_Response_Info_Malformed,
	MQTT_Request_Problem_Info_Malformed,
	MQTT_Connect_Deserialize_Remaining_Length_Failed,
	MQTT_Deserialize_User_Property_Name_Length_Failed,
	MQTT_Deserialize_User_Property_Value_Length_Failed,
}

MQTT_Error :: union {
	Serialize_Error,
	De_Serialize_Error,
	MQTT_No_Error,
}
