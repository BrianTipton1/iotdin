
package protocol

import "core:encoding/varint"
import "core:math/bits"


controlHeaderByte :: proc(packet_type: Packet_Type, flags: int) -> (control_header: byte) {
	enum_value := cast(int)packet_type

	b := bits.bitfield_insert(0, enum_value, 4, 4)
	b = bits.bitfield_insert(b, flags, 0, 4)

	control_header = byte(b)
	return
}

fixedHeader :: proc(
	buf: ^[dynamic]byte,
	packet_type: Packet_Type,
	remaining_length: []byte,
	flags: int,
) {
	control_header := controlHeaderByte(packet_type, flags)
	append(buf, control_header)
	append(buf, ..remaining_length[:])
}


encode_variable_int :: proc(value: u128) -> (size: int, error: MQTT_Error, var_int: [4]byte) {
	buf: [4]byte
	return varint.encode_uleb128(buf[:], value), buf
}

decode_var_int :: proc(value: []byte) -> (val: Maybe(MQTT_Var_Int), size: int, error: MQTT_Error) {
	valu128: u128
	valu128, size, error = varint.decode_uleb128_buffer(value)


	if size > 4 {
		error = .MQTT_Variable_Bytes_More_Than_Four
		return
	}
	if error == varint.Error.None {
		val = MQTT_Var_Int(valu128)
	}


	return
}
