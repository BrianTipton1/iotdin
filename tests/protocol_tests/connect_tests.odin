
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
@(private)
Case :: struct {
	packet: Packet,
	value:  protocol.Connect_Flags_Set,
}

@(test)
expect_packet_will_have_mqtt :: proc(t: ^testing.T) {
	packet := Packet{}

	buf := protocol.connect_variable_header_first_ten(packet)
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
		bs := transmute(bit_set[protocol.Connect_Flags])b
		testing.expectf(t, c.value == bs, "Case: %d. Expected: %d to be %d", i + 1, bs, c.value)
	}

}


@(test)
expect_packet_can_serialize_keep_alive :: proc(t: ^testing.T) {
	cases := []Case{{packet = Packet{username = ""}, value = {protocol.Connect_Flags.User_Name}}}

	for c, i in cases {
		b := protocol.connect_variable_header_first_ten(c.packet)
		out_packet := new(Packet, context.temp_allocator)
		err := protocol.deserialize_connect_variable_header_first_ten(b[:], out_packet)
	}
	testing.expect(t, true)
}
