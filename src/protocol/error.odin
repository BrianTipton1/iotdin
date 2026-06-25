package protocol

import "core:encoding/varint"

Serialize_Error :: enum {
	Binary_Data_Too_Long,
	None,
}

MQTT_Var_Int_Error :: enum {
	Variable_Bytes_More_Than_Four,
}

MQTT_Error :: union {
	Serialize_Error,
	MQTT_Var_Int_Error,
}
