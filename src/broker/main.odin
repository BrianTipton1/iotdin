package broker

import "core:time"
import "iotdin:transport"
main :: proc() {
	for {
		time.sleep(1)
		transport.recv_test()
	}
}
