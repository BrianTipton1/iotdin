package main

import "core:fmt"
import "iotdin:protocol"
import "iotdin:transport"

main :: proc() {
	fmt.println()

	buf := make([dynamic]byte)
	defer delete(buf)
	x := protocol.serialize(
	&buf,
	protocol.Connect_Packet {
		will = protocol.Will{qos = .At_Most_Once}, // TODO: need to still fix the will payload
		duplicate = false,
		username = "test",
		password = []byte{byte('P'), byte('A'), byte('S'), byte('S')},
		clean_start = true,
		payload = protocol.Connect_Payload {
			client_identifier = "dummyclient",
			will_properties = protocol.Connect_Will_Properties {
				will_delay_interval = 10,
				payload_format_indicator = false,
				message_expiry_interval = 20,
				content_type = "text/plain",
				response_topic = "will response topic",
				coorelation_data = nil,
				user_properties = nil,
				will_topic = "willtopic",
			},
		},
		properties = protocol.Connect_Properties {
			session_expiry_interval      = 50,
			maximum_packet_size          = 60,
			receive_maximum              = 70,
			topic_alias_maximum          = 80,
			request_response_information = true,
			request_problem_information  = true,
			user_properties              = []protocol.UserProperty {
				protocol.UserProperty{name = "x-iotdin-header", value = "1.0"},
				protocol.UserProperty{name = "some key", value = "some value"},
			},
			// authentication_method = "SCRAM-SHA-256",
			// authentication_data = hash.hash_string(.SHA256, "some auth data")
		},
	},
	)

	v := buf[:]
	// util.print(v)
	transport.sendTest(v)
}
