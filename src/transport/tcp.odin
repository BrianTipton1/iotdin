
package transport

import "core:fmt"
import "core:net"
import "core:thread"
import "iotdin:protocol"
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

handle_msg :: proc(sock: net.TCP_Socket) {
	buffer: [500]u8
	total_recv := 0
	for {
		bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])
		total_recv += bytes_recv
		if err_recv != nil {
			fmt.println("Failed to receive data")
		}
		received := buffer[:bytes_recv]
		util.print(received)
		if len(received) == 0 {
			fmt.println("Disconnecting client")
			break
		}

		util.print(buffer[:total_recv])
		connect, error := protocol.deserialize(buffer[:total_recv])
		fmt.println("")
	}

	net.close(sock)
}

recv_test :: proc() {
	endpoint := net.Endpoint {
		port    = 8080,
		address = net.IP4_Loopback,
	}


	sock, err := net.listen_tcp(endpoint)

	for {
		cli, _, err_accept := net.accept_tcp(sock)
		if err_accept != nil {
			fmt.println("Failed to accept TCP connection")
			continue
		}
		thread.create_and_start_with_poly_data(cli, handle_msg)
	}
}
