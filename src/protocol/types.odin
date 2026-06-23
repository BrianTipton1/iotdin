package protocol


QoSType :: enum {
	AtMostOnce  = 0, // Fire and Forget
	AtLeastOnce = 1, // PUBACK
	ExactlyOnce = 2, // PUBLISH, PUBREC, PUBREL, PUBCOMP
}
