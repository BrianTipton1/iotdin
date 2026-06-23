
package util

import "core:fmt"
import "core:net"

sendTest :: proc(data: []byte) {
	socket, err := net.create_socket(.IP4, .TCP)
	endpoint := net.Endpoint {
		port    = 1883,
		address = net.IP4_Loopback,
	}

	bindErr := net.bind(socket, endpoint)

	tcpSocket, listenErr := net.dial_tcp(endpoint)

	bytesWritten, sendError := net.send(tcpSocket, data)

	fmt.println("Bytes Written:", bytesWritten)
	fmt.println("Bytes Written is same as len:", bytesWritten == len(data))
	fmt.println("Send Error:", sendError)
}
