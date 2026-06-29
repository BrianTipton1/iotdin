
package transport

import "core:fmt"
import "core:net"
import "iotdin:util"

send_test :: proc(data: []byte) {
	socket, err := net.create_socket(.IP4, .TCP)
	endpoint := net.Endpoint {
		port    = 1883,
		address = net.IP4_Loopback,
	}

	bind_err := net.bind(socket, endpoint)

	tcp_socket, lisen_err := net.dial_tcp(endpoint)

	bytes_written, send_error := net.send(tcp_socket, data)
	if send_error == net.TCP_Send_Error.None {
		connack: [17]byte

		accept_client, accept_endpoint, l := net.accept_tcp(tcp_socket)
		recv_bytes_read, recv_err := net.recv_tcp(tcp_socket, connack[:])
		util.print_bin_string(connack[:recv_bytes_read])
		fmt.println(recv_bytes_read)
		fmt.println(recv_err)
	}
}
