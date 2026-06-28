
package protocol_tests

import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"
import "iotdin:protocol"
import "iotdin:util"


@(private)
Will :: protocol.Connect_Will
@(private)
Packet :: protocol.Connect_Packet

@(test)
expect_packet_will_have_mqtt :: proc(t: ^testing.T) {
	packet := Packet{}

	buf := protocol.serialize_connect_variable_header_first_ten(packet)
	testing.expect(t, buf[0] == 0x00, "")
	testing.expect(t, buf[1] == 0x04, "")
	testing.expect(t, buf[2] == byte('M'), "M")
	testing.expect(t, buf[3] == byte('Q'), "Q")
	testing.expect(t, buf[4] == byte('T'), "T")
	testing.expect(t, buf[5] == byte('T'), "T")
	testing.expect(t, buf[6] == 0x05, "")
}

@(test)
expect_packet_will_have_mqtt_variable_flags :: proc(t: ^testing.T) {
	Case :: struct {
		packet: Packet,
		value:  protocol.Connect_Flags_Set,
	}
	cases := []Case {
		{packet = Packet{username = ""}, value = {.User_Name}},
		{packet = Packet{password = []byte{}}, value = {.Password}},
		{packet = Packet{will = Will{}}, value = {.Will_Flag}},
		{packet = Packet{will = Will{qos = .At_Least_Once}}, value = {.Will_QOS, .Will_Flag}},
		{packet = Packet{will = Will{qos = .At_Most_Once}}, value = {.Will_Flag}},
		{packet = Packet{will = Will{qos = .Exactly_Once}}, value = {.Will_QOS2, .Will_Flag}},
		{packet = Packet{will = Will{retain = true}}, value = {.Will_Retain, .Will_Flag}},
		{packet = Packet{clean_start = true}, value = {.Clean_Start}},
	}

	for c, i in cases {
		b := protocol.connect_variable_flags(c.packet)
		bs := transmute(protocol.Connect_Flags_Set)b
		testing.expectf(t, c.value == bs, "Case: %d. Expected: %d to be %d", i + 1, bs, c.value)
	}

}


@(test)
expect_packet_can_serialize_keep_alive :: proc(t: ^testing.T) {
	packet := Packet {
		keep_alive = 16,
	}

	b := protocol.serialize_connect_variable_header_first_ten(packet)
	out_packet := new(Packet)
	defer free(out_packet)

	err := protocol.deserialize_connect_variable_header_first_ten(b[:], out_packet)
	testing.expect(t, packet.keep_alive == out_packet.keep_alive, "Keep alive should be same")
}

@(test)
expect_packet_will_exists :: proc(t: ^testing.T) {
	packet := Packet {
		will = Will{},
	}

	b := protocol.serialize_connect_variable_header_first_ten(packet)
	out_packet := new(Packet)
	defer free(out_packet)

	err := protocol.deserialize_connect_variable_header_first_ten(b[:], out_packet)
	_, will_exists := out_packet.will.?
	testing.expect(t, will_exists, "will should exist")
}

@(test)
expect_packet_will_not_exists :: proc(t: ^testing.T) {
	packet := Packet{}

	b := protocol.serialize_connect_variable_header_first_ten(packet)
	out_packet := new(Packet)
	defer free(out_packet)

	err := protocol.deserialize_connect_variable_header_first_ten(b[:], out_packet)
	_, will_exists := out_packet.will.?
	testing.expect(t, !will_exists, "will should not exist")
}


@(test)
expect_packet_without_will_flag_cant_have_qos :: proc(t: ^testing.T) {
	packets := []Packet {
		Packet{will = Will{qos = .At_Least_Once}},
		Packet{will = Will{qos = .Exactly_Once}},
	}

	for packet in packets {
		bytes := protocol.serialize_connect_variable_header_first_ten(packet)
		out_packet := new(Packet)
		defer free(out_packet)

		bytes[7] ~= 1 << 2
		err := protocol.deserialize_connect_variable_header_first_ten(bytes[:], out_packet)
		testing.expect(
			t,
			err == .MQTT_Will_Flag_Unset_With_QOS,
			"will should not have qos without will flag",
		)
	}
}


@(test)
expect_packet_without_will_flag_cant_retain :: proc(t: ^testing.T) {
	packet := Packet {
		will = Will{qos = .At_Most_Once, retain = true},
	}

	bytes := protocol.serialize_connect_variable_header_first_ten(packet)
	out_packet := new(Packet)
	defer free(out_packet)

	bytes[7] ~= 1 << 2
	err := protocol.deserialize_connect_variable_header_first_ten(bytes[:], out_packet)
	testing.expect(
		t,
		err == .MQTT_Will_Flag_Unset_With_Retain,
		"will should not have will retain without will flag",
	)
}

@(test)
expect_packet_qos_can_be_serialized :: proc(t: ^testing.T) {
	packets := []Packet {
		Packet{will = Will{qos = .At_Most_Once}},
		Packet{will = Will{qos = .At_Least_Once}},
		Packet{will = Will{qos = .Exactly_Once}},
	}

	for packet in packets {
		bytes := protocol.serialize_connect_variable_header_first_ten(packet)
		out_packet := new(Packet)
		defer free(out_packet)

		err := protocol.deserialize_connect_variable_header_first_ten(bytes[:], out_packet)

		will, will_exists := out_packet.will.?
		testing.expect(
			t,
			will_exists && will.qos == packet.will.(protocol.Connect_Will).qos,
			"will qos should match",
		)
	}
}


@(test)
expect_packet_user_name_flag_is_set :: proc(t: ^testing.T) {
	packet := Packet {
		username = "some user",
	}

	bytes := protocol.serialize_connect_variable_header_first_ten(packet)
	out_packet := new(Packet)
	defer free(out_packet)

	err := protocol.deserialize_connect_variable_header_first_ten(bytes[:], out_packet)

	_, user_name_exists := out_packet.username.?
	testing.expect(t, user_name_exists, "user name should exist")
}

@(test)
expect_packet_password_flag_is_set :: proc(t: ^testing.T) {
	pass := []byte{byte('P'), byte('A'), byte('S'), byte('S')}
	packet := Packet {
		password = pass,
	}

	bytes := protocol.serialize_connect_variable_header_first_ten(packet)
	out_packet := new(Packet)
	defer free(out_packet)

	err := protocol.deserialize_connect_variable_header_first_ten(bytes[:], out_packet)

	_, user_name_exists := out_packet.password.?
	testing.expect(t, user_name_exists, "password should exist")
}
