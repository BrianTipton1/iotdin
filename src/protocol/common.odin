
package protocol

import "core:encoding/endian"
import "core:encoding/varint"
import "core:math/bits"


encode_control_header_byte :: proc(
	packet_type: Packet_Type,
	flags: int,
) -> (
	control_header: byte,
) {
	enum_value := cast(int)packet_type

	b := bits.bitfield_insert(0, enum_value, 4, 4)
	b = bits.bitfield_insert(b, flags, 0, 4)

	control_header = byte(b)
	return
}

decode_packet_type :: proc(first_byte: byte) -> (packet_type: Packet_Type) {
	res := bits.bitfield_extract(first_byte, 4, 4)
	packet_type = transmute(Packet_Type)int(res)
	return
}

make_packet :: proc(buf: []byte) -> (packet: ^Packet) {
	packet = new(Packet)
	packet_type := decode_packet_type(buf[0])

	// TODO: Fill out as impl, remove partial
	#partial switch packet_type {
	case .CONNECT:
		packet^ = Connect_Packet{}
	}
	return
}

serialize_fixed_header :: proc(
	buf: ^[dynamic]byte,
	packet_type: Packet_Type,
	remaining_length: []byte,
	flags: int,
) {
	control_header := encode_control_header_byte(packet_type, flags)
	append(buf, control_header)
	append(buf, ..remaining_length[:])
}


encode_variable_int :: proc(u28: U28) -> (size: int, var_int: [4]byte) {
	val := cast(u128)u28.value
	size, _ = varint.encode_uleb128(var_int[:], val)

	return
}

decode_var_int :: proc(value: []byte) -> (var_int: Var_Int, ok: bool) {
	valu128, size, decode_error := varint.decode_uleb128_buffer(value)

	if size > 4 {
		return var_int, false
	}

	if decode_error == .None {
		u28val, u28ok := make_u28(valu128)
		var_int = Var_Int {
			u28  = u28val,
			size = size,
		}
		return var_int, u28ok
	}

	return
}
