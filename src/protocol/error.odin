package protocol

import "core:encoding/varint"

MQTT_Var_Int_Error :: enum {
	MQTT_Variable_Bytes_More_Than_Four,
}

Serialize_Connect_Error :: enum {
	None,
}

MQTT_Error :: union {
	Serialize_Connect_Error,
	MQTT_Var_Int_Error,
	varint.Error,
}



