package protocol

import "base:intrinsics"
import "core:encoding/endian"
import "core:unicode"

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


read_two_byte_slice :: proc(buf: []byte) -> (n_bytes: u16, err: De_Serialize_Error) {
	u16_parsed: bool
	n_bytes, u16_parsed = endian.get_u16(buf, .Big)

	if !u16_parsed {
		return n_bytes, .Two_Byte_Integer_Incorrect_Size
	}

	return n_bytes, .None
}


make_u28 :: proc(value: $T) -> (v: U28, ok: bool) where intrinsics.type_is_integer(T) {
	val := int(value)
	if val > int(U28_MAX) || val < 0 {
		return v, false
	}

	return U28(value), true
}


wrap_endian :: proc(
	$f: proc "contextless" (buf: []byte, bo: endian.Byte_Order) -> ($T, bool),
) -> (
	out_proc: proc(buf: []byte) -> (T, bool),
) {
	return proc(buf: []byte) -> (T, bool) {
			return f(buf, .Big)
		}
}

Converter_Type :: struct($T: typeid) {
	fn: proc(buf: []byte) -> (value: T, ok: bool),
}

deserialize_utf8_string :: proc(
	buf: []byte,
	len_err: De_Serialize_Error,
	malformed_err: De_Serialize_Error,
) -> (
	deserialized: string,
	len_read: int,
	err: De_Serialize_Error,
) {
	if len(buf) < 2 {
		err = len_err
		return
	}
	u8_reader := reader_for_type(u16)
	len_str, len_okay := u8_reader.fn(buf)
	if !len_okay {
		err = len_err
		return
	}

	if len(buf) < int(len_str) {
		err = malformed_err
		return
	}

	str_bytes := buf[2:len_str]

	for b in str_bytes {
		if unicode.is_control(rune(b)) {
			err = malformed_err
			return
		}
	}

	deserialized = string(str_bytes)
	len_read = 2 + int(len_str)

	return
}


reader_for_type :: proc($T: typeid) -> (converter: Converter_Type(T)) {
	when T == byte {
		converter.fn = slices.head
	} else when T == u32 {
		converter.fn = wrap_endian(endian.get_u32)
	} else when T == u16 {
		converter.fn = wrap_endian(endian.get_u16)
	} else when T == MQTT_Var_Int {
		converter.fn = decode_var_int
	} else {
		#panic("No impl")
	}
	return
}
