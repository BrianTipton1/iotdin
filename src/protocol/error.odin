package protocol

import "core:encoding/varint"

MQTT_Var_Int_Error :: enum {
	ValueTooLarge,
}

MQTT_Encoding_Var_Int_Error :: union {
	MQTT_Var_Int_Error,
	varint.Error,
}
