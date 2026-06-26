
package transport

import "iotdin:util"
import "core:fmt"
import "core:net"

sendTest :: proc(data: []byte) {
	socket, err := net.create_socket(.IP4, .TCP)
	endpoint := net.Endpoint {
		port    = 1883,
		address = net.IP4_Loopback,
	}

	bind_err := net.bind(socket, endpoint)

	tcpSocket, listenErr := net.dial_tcp(endpoint)

	bytesWritten, sendError := net.send(tcpSocket, data)
	if sendError == net.TCP_Send_Error.None {
		connack: [17]byte

		accept_client, accept_endpoint, l := net.accept_tcp(tcpSocket)
		recv_bytes_read, recv_err := net.recv_tcp(tcpSocket, connack[:])
		util.print(connack[:recv_bytes_read])
		fmt.println(recv_bytes_read)
		fmt.println(recv_err)
	}
}
