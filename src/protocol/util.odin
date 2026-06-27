package protocol

import "base:intrinsics"
import "core:encoding/endian"

append_scalar :: proc(
	buf: ^[dynamic]byte,
	value: $T,
) -> MQTT_Error where intrinsics.type_is_integer(T) {
	when size_of(T) == 1 {
		append(buf, byte(value))
	} else when size_of(T) == 2 {
		b := transmute([2]byte)(u16be(value))
		append(buf, ..b[:])
	} else when size_of(T) == 4 {
		b := transmute([4]byte)(u32be(value))
		append(buf, ..b[:])
	} else {
		#panic("append_property: unsupported integer size")
	}
	return MQTT_No_Error.None
}

append_bool :: proc(buf: ^[dynamic]byte, value: bool) -> MQTT_Error {
	append(buf, byte(1) if value else byte(0))
	return MQTT_No_Error.None
}

append_string :: proc(buf: ^[dynamic]byte, s: string) -> MQTT_Error {
	length := transmute([2]byte)(u16be(len(s)))
	append(buf, ..length[:])
	append(buf, ..transmute([]byte)s)
	return MQTT_No_Error.None
}

append_binary :: proc(buf: ^[dynamic]byte, data: []byte) -> MQTT_Error {
	length := transmute([2]byte)(u16be(len(data)))
	append(buf, ..length[:])
	append(buf, ..data)
	return MQTT_No_Error.None
}


append_pair :: proc(buf: ^[dynamic]byte, name: string, value: string) -> MQTT_Error {
	name_len := transmute([2]byte)(u16be(len(name)))
	append(buf, ..name_len[:])
	append(buf, ..transmute([]byte)name)
	value_len := transmute([2]byte)(u16be(len(value)))
	append(buf, ..value_len[:])
	append(buf, ..transmute([]byte)value)
	return MQTT_No_Error.None
}


append_varint :: proc(buf: ^[dynamic]byte, value: U28) -> MQTT_Error {
	size, encoded := encode_variable_int(value)
	append(buf, ..encoded[:size])
	return MQTT_No_Error.None
}


read_two_byte_slice :: proc(buf: []byte) -> (n_bytes: u16, err: DeSerialize_Error) {
	u16_parsed: bool
	n_bytes, u16_parsed = endian.get_u16(buf, .Big)

	if !u16_parsed {
		return n_bytes, .Two_Byte_Integer_Incorrect_Size
	}

	return n_bytes, .None
}


make_u28 :: proc(value: $T) -> (v: U28, ok: bool) where intrinsics.type_is_integer(T) {
	if int(value) > int(U28_MAX) {
		return v, false
	}

	return U28(value), true
}
