
package protocol_tests

import "core:crypto/hash"
import "core:fmt"
import "core:log"
import "core:slice"
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

	_, password_exists := out_packet.password.?
	testing.expect(t, password_exists, "password should exist")
}


@(test)
deserialize_packet :: proc(t: ^testing.T) {

	context.allocator = context.temp_allocator
	user_properties := new([dynamic]protocol.UserProperty)
	append(
		user_properties,
		..[]protocol.UserProperty {
			protocol.UserProperty{name = "x-iotdin-header", value = "71"},
			protocol.UserProperty{name = "some key", value = "some value 1"},
			protocol.UserProperty{name = "some new key", value = "some new value"},
		},
	)
	packet := protocol.Connect_Packet {
		duplicate = false,
		username = "test",
		protocol_version = int(protocol.MQTT_VERSION),
		protocol = protocol.PROTOCOL_STR,
		password = []byte{byte('P'), byte('A'), byte('S'), byte('S')},
		clean_start = true,
		client_identifier = "dummyclient",
		keep_alive = 55,
		will = protocol.Connect_Will {
			qos = .At_Least_Once,
			properties = protocol.Connect_Will_Properties {
				will_delay_interval = 10,
				payload_format_indicator = false,
				message_expiry_interval = 20,
				content_type = "text/plain",
				response_topic = "will response topic",
				coorelation_data = nil,
				user_properties = nil,
			},
			will_topic = "willtopic",
			payload = "some payload nice wowzers",
		},
		properties = protocol.Connect_Properties {
			session_expiry_interval = 50,
			maximum_packet_size = 60,
			receive_maximum = 70,
			topic_alias_maximum = 80,
			request_response_information = true,
			request_problem_information = true,
			user_properties = user_properties,
			authentication_method = "SCRAM-SHA-256",
			authentication_data = hash.hash_string(.SHA256, "some auth data"),
		},
	}


	packet_bytes := make([dynamic]byte)
	protocol.serialize(&packet_bytes, packet)

	deserialized_packet_ptr, deserilized_err := protocol.deserialize(packet_bytes[:])
	deserialized_packet, ok := deserialized_packet_ptr^.?


	error, _ := deserilized_err.(protocol.De_Serialize_Error)
	testing.expect(
		t,
		error == protocol.De_Serialize_Error.None,
		"expect packet to deserialize with no errors",
	)


	testing.expect(
		t,
		packet.protocol_version == deserialized_packet.protocol_version,
		"expect deserializing protocol version should match",
	)
	testing.expect(
		t,
		packet.protocol == deserialized_packet.protocol,
		"expect deserializing protocol should match",
	)
	testing.expect(
		t,
		packet.clean_start == deserialized_packet.clean_start,
		"expect deserializing clean start should match",
	)

	deserialized_will, deserialized_will_okay := deserialized_packet.will.?
	will, will_okay := packet.will.?
	testing.expect(
		t,
		will_okay == deserialized_will_okay,
		"expect deserializing will should match",
	)
	testing.expect(
		t,
		will.qos == deserialized_will.qos,
		"expect deserializing will qos should match",
	)
	testing.expect(
		t,
		will.retain == deserialized_will.retain,
		"expect deserializing will retain should match",
	)
	_, deserialized_username_okay := deserialized_packet.username.?
	_, username_okay := packet.username.?

	testing.expect(
		t,
		username_okay == deserialized_username_okay,
		"expect deserializing username should match",
	)

	_, deserialized_password_okay := deserialized_packet.password.?
	_, password_okay := packet.password.?

	testing.expect(
		t,
		password_okay == deserialized_password_okay,
		"expect deserializing password should match",
	)
	user_props, user_props_okay := packet.properties.user_properties.?
	deserialized_user_props, deserialized_user_props_okay := deserialized_packet.properties.user_properties.?
	if user_props_okay {
		testing.expect(
			t,
			deserialized_user_props_okay && len(user_props) == len(deserialized_user_props),
			"deserialized should have same number of properties",
		)

		if deserialized_user_props_okay {
			success: bool = true
			for deserialized_prop in deserialized_user_props {
				success &= slice.contains(user_props^[:], deserialized_prop)
			}

			testing.expect(t, success, "props should be the same")
		}
	}

	authentication_method, authentication_method_okay := packet.properties.authentication_method.?
	deserialized_authentication_method, deserialized_authentication_method_okay := packet.properties.authentication_method.?
	if authentication_method_okay {
		testing.expect(
			t,
			deserialized_authentication_method_okay &&
			authentication_method == deserialized_authentication_method,
			"deserialized auth method should equal",
		)
	}

	authentication_data, authentication_data_okay := packet.properties.authentication_data.?
	deserialized_authentication_data, deserialized_authentication_data_okay := packet.properties.authentication_data.?
	if authentication_data_okay {
		testing.expect(
			t,
			deserialized_authentication_data_okay &&
			slice.equal(authentication_data, deserialized_authentication_data),
			"deserialized auth data should equal",
		)
	}

	free_all(context.temp_allocator)
}
