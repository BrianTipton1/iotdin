package broker

import "core:container/xar"
import "core:fmt"
import "core:mem"
import "core:nbio"
import "core:net"
import "core:os"
import "core:thread"
import "oot:protocol"
import "oot:util"

Broker_Config :: struct {
	port:      u16,
	n_threads: int,
}


no_op :: proc(_: ^nbio.Operation) {}

start_broker :: proc(config: Broker_Config) {

	workers: thread.Pool
	thread.pool_init(&workers, context.allocator, config.n_threads)
	thread.pool_start(&workers)
	err := nbio.acquire_thread_event_loop()
	defer nbio.release_thread_event_loop()

	assert(err == nil)
	tcp_socket, listen_err := nbio.listen_tcp(
		{address = nbio.IP4_Loopback, port = int(config.port)},
	)
	assert(listen_err == nil)
	nbio.accept_poly(tcp_socket, &workers, on_accept)

	err = nbio.run()
}


main :: proc() {
	start_broker({port = protocol.MQTT_DEFAULT_PORT, n_threads = os.get_processor_core_count()})
}

Connection :: struct {
	loop:       ^nbio.Event_Loop,
	socket:     nbio.TCP_Socket,
	packet_len: protocol.MQTT_Var_Int,
	header:     []byte,
}


on_accept :: proc(op: ^nbio.Operation, workers: ^thread.Pool) {
	assert(op.accept.err == nil)
	nbio.accept_poly(op.accept.socket, workers, on_accept)

	thread.pool_add_task(
		workers,
		context.allocator,
		handle_connection,
		new_clone(Connection{loop = op.l, socket = op.accept.client}),
	)
}

on_start_recv_mqtt_packet :: proc(op: ^nbio.Operation, connection: ^Connection) {
	buf := op.recv.bufs[0]
	if len(buf) < 5 {
		return
	}
	packet_len, ok := protocol.decode_var_int(buf[1:5])

	connection.packet_len = packet_len
	connection.header = buf

	body_buf := make([dynamic]byte, packet_len.u28.value)
	nbio.recv_poly(op.recv.socket, {body_buf[:]}, connection, on_read_mqtt_packet)
}

on_read_mqtt_packet :: proc(op: ^nbio.Operation, connection: ^Connection) {
	packet_len := connection.packet_len
	packet_rest := op.recv.bufs[0]
	header := connection.header

	packet_buf := make([dynamic]byte)
	fmt.println("")
	append(&packet_buf, ..header)
	append(&packet_buf, ..packet_rest[:])

	util.print_bits(header)
	util.print_bits(packet_rest[:])
	util.print_bits(packet_buf[:])

	packet, err := protocol.deserialize(packet_buf[:])
	fmt.println("")
}

handle_connection :: proc(t: thread.Task) {
	connection := (^Connection)(t.data)
	buf: [5]byte

	operation := nbio.recv_poly(
		connection.socket,
		{buf[:]},
		connection,
		on_start_recv_mqtt_packet,
		l = connection.loop,
	)
}

on_sent :: proc(op: ^nbio.Operation, connection: ^Connection) {
	assert(op.send.err == nil)
	nbio.close(connection.socket)
	// nbio.close(connection.socket)
	free(connection)
}
