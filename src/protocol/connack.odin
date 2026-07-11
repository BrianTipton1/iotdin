package protocol

import "core:testing"

Connack_Packet :: struct {
	session_present:     bool,
	connect_reason_code: Connect_Reason_Code,
	properties:          Connack_Properties,
}

Connack_Properties :: struct {
	session_expiry_interval:            u32,
	receive_maximum:                    u16,
	maximum_qos:                        QoS_Type,
	retain_available:                   Maybe(bool),
	maximum_packet_size:                Maybe(u32),
	assigned_client_identifier:         Maybe(string),
	topic_alias_maximum:                Maybe(u16),
	reason_string:                      Maybe(string),
	user_properties:                    Maybe(^[dynamic]UserProperty),
	wild_card_subscription_available:   Maybe(bool),
	subscription_identifiers_available: Maybe(bool),
	shared_subscription_available:      Maybe(bool),
	server_keep_alive:                  Maybe(u16),
	response_information:               Maybe(string),
	server_reference:                   Maybe(string),
	authentication_method:              Maybe(string),
	authentication_data:                Maybe([]byte),
}

Connect_Reason_Code :: enum byte {
	Success                       = 0x00,
	Unspecified_Error             = 0x80,
	Malformed_Packet              = 0x81,
	Protocol_Error                = 0x82,
	Implementation_Specific_Error = 0x83,
	Unsupported_Protocol_Version  = 0x84,
	Client_Identifier_Not_Valid   = 0x85,
	Bad_User_Name_Or_Password     = 0x86,
	Not_Authorized                = 0x87,
	Server_Unavailable            = 0x88,
	Server_Busy                   = 0x89,
	Banned                        = 0x8A,
	Bad_Authentication_Method     = 0x8C,
	Topic_Name_Invalid            = 0x90,
	Packet_Too_Large              = 0x90,
	Quota_Exceeded                = 0x97,
	Payload_Format_Invalid        = 0x99,
	Retain_Not_Supported          = 0x9A,
	QoS_Not_Supported             = 0x9B,
	Use_Another_Server            = 0x9C,
	Server_Moved                  = 0x9D,
	Connection_Rate_Exceeded      = 0x9F,
}

serialize_connack_properties :: proc(packet: Connack_Packet) -> (properties: ^[dynamic]byte) {
	props := make([dynamic]byte)
	properties = &props
	properties_just_data := make([dynamic]byte)
	defer delete(properties_just_data)


	append_property(
		&properties_just_data,
		.Session_Expiry_Interval,
		packet.properties.session_expiry_interval,
	)
	append_property(&properties_just_data, .Receive_Maximum, packet.properties.receive_maximum)

	max_qos := packet.properties.maximum_qos
	if max_qos != .Exactly_Once {
		append_property(
			&properties_just_data,
			.Receive_Maximum,
			false if max_qos == .At_Most_Once else true,
		)
	}

	retain_available, retain_available_okay := packet.properties.retain_available.?
	if retain_available_okay {
		append_property(&properties_just_data, .Retain_Available, retain_available)
	}

	max_packet_size, max_packet_size_available := packet.properties.maximum_packet_size.?
	if max_packet_size_available {
		append_property(&properties_just_data, .Maximum_Packet_Size, max_packet_size)
	}

	assigned_client_identifier, assigned_client_identifier_okay := packet.properties.assigned_client_identifier.?
	if assigned_client_identifier_okay {
		append_property(
			&properties_just_data,
			.Assigned_Client_Identifier,
			assigned_client_identifier,
		)
	}

	topic_alias_max, topic_alias_max_okay := packet.properties.topic_alias_maximum.?
	if topic_alias_max_okay {
		append_property(&properties_just_data, .Topic_Alias_Maximum, topic_alias_max)
	}


	reason_string, reason_string_okay := packet.properties.reason_string.?
	if reason_string_okay {
		append_property(&properties_just_data, .Reason_String, reason_string)
	}


	user_properties, user_properties_okay := packet.properties.user_properties.?
	if user_properties_okay {
		for prop in user_properties {
			append_property(&properties_just_data, .User_Property, prop.name, prop.value)
		}
	}

	wild_card_subscription_available, wild_card_subscription_available_okay := packet.properties.wild_card_subscription_available.?
	if wild_card_subscription_available_okay {
		append_property(
			&properties_just_data,
			.Wildcard_Subscription_Available,
			wild_card_subscription_available,
		)

	}

	subscription_identifiers_available, subscription_identifiers_available_okay := packet.properties.subscription_identifiers_available.?
	if subscription_identifiers_available_okay {
		append_property(
			&properties_just_data,
			.Shared_Subscription_Available,
			subscription_identifiers_available,
		)
	}

	server_keep_alive, server_keep_alive_okay := packet.properties.server_keep_alive.?
	if server_keep_alive_okay {
		append_property(&properties_just_data, .Server_Keep_Alive, server_keep_alive)
	}

	response_information, response_information_okay := packet.properties.response_information.?
	if response_information_okay {
		append_property(&properties_just_data, .Response_Information, response_information)
	}

	server_reference, server_reference_okay := packet.properties.server_reference.?
	if server_reference_okay {
		append_property(&properties_just_data, .Server_Reference, server_reference)
	}


	authentication_method, authentication_method_okay := packet.properties.authentication_method.?
	if authentication_method_okay {
		append_property(&properties_just_data, .Authentication_Method, authentication_method)
	}

	authentication_data, authentication_data_okay := packet.properties.authentication_data.?
	if authentication_data_okay {
		append_property(&properties_just_data, .Authentication_Data, authentication_data)
	}


	return
}

serialize_connack_packet :: proc(
	buf: ^[dynamic]byte,
	packet: Connack_Packet,
) -> (
	error: Serialize_Error,
) {


	return
}

deserialize_connack_packet :: proc(
	buf: []byte,
	packet: ^Connack_Packet,
) -> (
	error: De_Serialize_Error,
) {

	return
}
