
package protocol

import "core:encoding/varint"
import "core:fmt"
import "core:math"
import "core:math/bits"
import "iotdin:util"


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


Variable_Byte_Bit :: enum u8 {
	Bit0,
	Bit1,
	Bit2,
	Bit3,
	Bit4,
	Bit5,
	Bit6,
	Continuation,
}
Variable_Byte_Bits :: bit_set[Variable_Byte_Bit;byte]

encode_variable_int :: proc(
	buf: ^[4]byte,
	value: u128,
) -> (
	size: Maybe(int),
	error: MQTT_Encoding_Var_Int_Error,
) {
	max := math.pow2_f64(128) - 1
	if (cast(f64)value >= max) {
		return nil, .ValueTooLarge
	}
	return varint.encode_uleb128(buf[:], value)
}
