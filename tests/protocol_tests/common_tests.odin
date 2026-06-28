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
		v, err := protocol.make_u28(c.value)
		testing.expect(t, err, "Making U28 has error")
		size, var_int := protocol.encode_variable_int(v)
		testing.expect(t, size == c.size, "incorrect size")
		testing.expect(t, var_int[0] == c.expected[0])
		testing.expect(t, var_int[1] == c.expected[1])
		testing.expect(t, var_int[2] == c.expected[2])
		testing.expect(t, var_int[3] == c.expected[3])
	}
}

@(test)
expect_encode_variable_byte_buf_too_small :: proc(t: ^testing.T) {
	negative, negative_ok := protocol.make_u28(-1)
	testing.expect(t, !negative_ok, "negatives not allowed")
	exact, exact_ok := protocol.make_u28(protocol.U28_MAX)
	testing.expect(t, exact_ok, "value should fit into U28")
	testing.expect(t, exact.value == protocol.U28_MAX, "exact should match")
	bigger, bigger_ok := protocol.make_u28(protocol.U28_MAX + 1)
	testing.expect(t, !bigger_ok, "value should be too large")
}


@(test)
expect_decode_valid :: proc(t: ^testing.T) {
	Case :: struct {
		buf:   []u8,
		value: protocol.U28,
		size:  int,
	}
	cases := []Case {
		{buf = {0x00}, value = protocol.U28(0), size = 1},
		{buf = {0x7F}, value = protocol.U28(127), size = 1},
		{buf = {0x80, 0x01}, value = protocol.U28(128), size = 2},
		{buf = {0xFF, 0x7F}, value = protocol.U28(16_383), size = 2},
		{buf = {0x80, 0x80, 0x01}, value = protocol.U28(16_384), size = 3},
		{buf = {0xFF, 0xFF, 0x7F}, value = protocol.U28(2_097_151), size = 3},
		{buf = {0x80, 0x80, 0x80, 0x01}, value = protocol.U28(2_097_152), size = 4},
		{buf = {0xFF, 0xFF, 0xFF, 0x7F}, value = protocol.U28(268_435_455), size = 4},
	}
	for c in cases {
		value, err := protocol.decode_var_int(c.buf)
		testing.expectf(t, err, "buf %v: unexpected error %v", c.buf, err)
		testing.expectf(
			t,
			value == c.value,
			"buf %v: got value %v, want %v",
			c.buf,
			value,
			c.value,
		)
	}
}

@(test)
expect_decode_too_large :: proc(t: ^testing.T) {
	buf := []u8{0xFF, 0xFF, 0xFF, 0xFF, 0x01}
	_, ok := protocol.decode_var_int(buf)
	testing.expect(t, !ok, "value should be too large")
}
