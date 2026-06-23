package protocol_tests

import "core:encoding/varint"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"
import "iotdin:protocol"

@(test)
expect_variable_byte :: proc(t: ^testing.T) {

	buf: [4]byte
	size, err := protocol.encode_variable_int(&buf, 127)
	errStr, ok := fmt.enum_value_to_string(err.(varint.Error))
	if ok {
		log.info("Its a varint error result")
	} else {
		log.warn("Its not a varint error result")
	}

	msg := strings.concatenate({"Error when encoding:", errStr})
	testing.expect(t, err == .None, msg)
}
