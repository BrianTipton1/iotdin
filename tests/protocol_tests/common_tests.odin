package protocol_tests

import "core:encoding/varint"
import "core:log"
import "core:mem"
import "core:slice"
import "core:testing"
import "iotdin:protocol"


// Kinda redundant and partially testing varint library and prob should be removed
@(test)
expect_encode_variable_byte_max :: proc(t: ^testing.T) {
	cases := []struct {
		value:    u32,
		size:     int,
		expected: [4]u8,
	} {
		{value = 127, size = 1, expected = {0x7F, 0x00, 0x00, 0x00}},
		{value = 16383, size = 2, expected = {0xFF, 0x7F, 0x00, 0x00}},
		{value = 2097151, size = 3, expected = {0xFF, 0xFF, 0x7F, 0x00}},
		{value = 268435455, size = 4, expected = {0xFF, 0xFF, 0xFF, 0x7F}},
	}

	for c in cases {
		size, err, var_int := protocol.encode_variable_int(cast(u128)c.value)
		testing.expect(t, err == varint.Error.None, "result has error")
		testing.expect(t, size == c.size, "incorrect size")
		testing.expect(t, var_int[0] == c.expected[0])
		testing.expect(t, var_int[1] == c.expected[1])
		testing.expect(t, var_int[2] == c.expected[2])
		testing.expect(t, var_int[3] == c.expected[3])
	}
}

@(test)
expect_encode_variable_byte_buf_too_small :: proc(t: ^testing.T) {
	size, err, var_int := protocol.encode_variable_int(268435456)
	testing.expect(t, err == .Buffer_Too_Small, "Buffer should be too small")
}


@(test)
expect_decode_valid :: proc(t: ^testing.T) {
	Case :: struct {
		buf:   []u8,
		value: protocol.MQTT_Var_Int,
		size:  int,
	}
	cases := []Case {
		{buf = {0x00}, value = 0, size = 1},
		{buf = {0x7F}, value = 127, size = 1},
		{buf = {0x80, 0x01}, value = 128, size = 2},
		{buf = {0xFF, 0x7F}, value = 16_383, size = 2},
		{buf = {0x80, 0x80, 0x01}, value = 16_384, size = 3},
		{buf = {0xFF, 0xFF, 0x7F}, value = 2_097_151, size = 3},
		{buf = {0x80, 0x80, 0x80, 0x01}, value = 2_097_152, size = 4},
		{buf = {0xFF, 0xFF, 0xFF, 0x7F}, value = 268_435_455, size = 4},
	}
	for c in cases {
		value, size, err := protocol.decode_var_int(c.buf)
		testing.expectf(t, err == .None, "buf %v: unexpected error %v", c.buf, err)
		testing.expectf(
			t,
			value == c.value,
			"buf %v: got value %v, want %v",
			c.buf,
			value,
			c.value,
		)
		testing.expectf(t, size == c.size, "buf %v: got size %v, want %v", c.buf, size, c.size)
	}
}

@(test)
expect_decode_too_large :: proc(t: ^testing.T) {
	buf := []u8{0xFF, 0xFF, 0xFF, 0xFF, 0x01}
	_, _, err := protocol.decode_var_int(buf)
	testing.expect(t, err == .Variable_Bytes_More_Than_Four, "value should be too large")
}
