#!/usr/bin/env bash
#
# mqtt_connect.sh — connect an MQTT client to a broker with customizable values.
# Wraps mosquitto_pub / mosquitto_sub. Override only the flags you need.
set -euo pipefail
# ---- Defaults (override via flags) ------------------------------------------
MODE="sub"                  # sub | pub
HOST="localhost"
PORT="1883"
TOPIC="test/topic"
MESSAGE="hello"             # used in pub mode
QOS="0"                     # 0 | 1 | 2
CLIENT_ID="client-$$"       # $$ = this script's PID, keeps it unique
KEEPALIVE="60"
USERNAME="my_user"
PASSWORD="my_pass"
CAFILE=""                   # path to CA cert -> enables TLS
RETAIN="false"              # pub mode: retain message on broker
# ---- Last Will & Testament (broker publishes this on ungraceful disconnect) -
WILL_TOPIC="clients/$CLIENT_ID/status"  # blank to disable the will entirely
WILL_PAYLOAD="offline"                  # arbitrary payload
WILL_QOS="0"                            # 0 | 1 | 2
WILL_RETAIN="false"                     # retain the will message on the broker
# ---- MQTT 5 properties (need mqttv5, which -V sets below; blank = omit) ------
# CONNECT-level properties:
CONNECT_SESSION_EXPIRY="3600"           # seconds; 0 = expire at disconnect
CONNECT_RECEIVE_MAX="100"               # max in-flight QoS>0 messages inbound
CONNECT_UPROP_KEY="client-flavor"       # one CONNECT user-property (key/value)
CONNECT_UPROP_VAL="vanilla"
# WILL-level properties (only applied when a will-topic is set):
WILL_DELAY="10"                         # secs broker waits before sending will
WILL_MSG_EXPIRY="120"                   # will-message expiry, seconds
WILL_CONTENT_TYPE="text/plain"          # will-message content-type
WILL_UPROP_KEY="event"                  # one WILL user-property (key/value)
WILL_UPROP_VAL="ungraceful-exit"
usage() {
cat <<EOF
Usage: $0 [options]
  -M MODE       sub or pub            (default: $MODE)
  -h HOST       broker host           (default: $HOST)
  -p PORT       broker port           (default: $PORT)
  -t TOPIC      topic                 (default: $TOPIC)
  -m MESSAGE    payload (pub only)    (default: $MESSAGE)
  -q QOS        0, 1, or 2            (default: $QOS)
  -i CLIENT_ID  client identifier     (default: $CLIENT_ID)
  -k KEEPALIVE  keepalive seconds     (default: $KEEPALIVE)
  -u USERNAME   auth username         (optional)
  -P PASSWORD   auth password         (optional)
  -c CAFILE     CA cert path -> TLS   (optional)
  -r            retain (pub only)
  -w WILL_TOPIC    will topic (blank disables)  (default: $WILL_TOPIC)
  -W WILL_PAYLOAD  will payload                 (default: $WILL_PAYLOAD)
  -Q WILL_QOS      will QoS 0/1/2               (default: $WILL_QOS)
  -R               retain the will message
  -H            show this help
(MQTT 5 properties are configured via the defaults block at the top of the script.)
Examples:
$0 -M sub -h broker.local -p 8883 -t sensors/# -c ca.crt
$0 -M pub -h 10.0.0.5 -t devices/1/cmd -m "on" -q 1 -r -u alice -P secret
$0 -M sub -t sensors/# -w clients/sensor-1/status -W "lost" -Q 1 -R
EOF
exit 0
}
# ---- Parse flags ------------------------------------------------------------
# Note: -h is the broker host here, not help. Use -H for help.
while getopts "M:h:p:t:m:q:i:k:u:P:c:rw:W:Q:RH" opt; do
case "$opt" in
M) MODE="$OPTARG" ;;
h) HOST="$OPTARG" ;;
p) PORT="$OPTARG" ;;
t) TOPIC="$OPTARG" ;;
m) MESSAGE="$OPTARG" ;;
q) QOS="$OPTARG" ;;
i) CLIENT_ID="$OPTARG" ;;
k) KEEPALIVE="$OPTARG" ;;
u) USERNAME="$OPTARG" ;;
P) PASSWORD="$OPTARG" ;;
c) CAFILE="$OPTARG" ;;
r) RETAIN="true" ;;
w) WILL_TOPIC="$OPTARG" ;;
W) WILL_PAYLOAD="$OPTARG" ;;
Q) WILL_QOS="$OPTARG" ;;
R) WILL_RETAIN="true" ;;
H) usage ;;
*) usage ;;
esac
done
# ---- Pick the client binary -------------------------------------------------
case "$MODE" in
sub) BIN="mosquitto_sub" ;;
pub) BIN="mosquitto_pub" ;;
*)   echo "Error: MODE must be 'sub' or 'pub' (got '$MODE')" >&2; exit 1 ;;
esac
command -v "$BIN" >/dev/null 2>&1 || {
echo "Error: $BIN not found. Install the mosquitto clients (e.g. apt install mosquitto-clients)." >&2
exit 1
}
# ---- Build the argument list ------------------------------------------------
# Using an array keeps spaces/quoting safe.
args=( -h "$HOST" -p "$PORT" -t "$TOPIC" -q "$QOS" -i "$CLIENT_ID" -k "$KEEPALIVE" -V "mqttv5")
[[ -n "$USERNAME" ]] && args+=( -u "$USERNAME" )
[[ -n "$PASSWORD" ]] && args+=( -P "$PASSWORD" )
[[ -n "$CAFILE"   ]] && args+=( --cafile "$CAFILE" )
# CONNECT-level MQTT 5 properties (-D <packet> <name> <value>).
[[ -n "$CONNECT_SESSION_EXPIRY" ]] && args+=( -D CONNECT session-expiry-interval "$CONNECT_SESSION_EXPIRY" )
[[ -n "$CONNECT_RECEIVE_MAX"    ]] && args+=( -D CONNECT receive-maximum "$CONNECT_RECEIVE_MAX" )
# user-property takes a key AND a value, so it's two args after the name.
[[ -n "$CONNECT_UPROP_KEY"      ]] && args+=( -D CONNECT user-property "$CONNECT_UPROP_KEY" "$CONNECT_UPROP_VAL" )
# Will: only attach when a will-topic is set. --will-payload/qos/retain and the
# -D WILL properties are only valid alongside --will-topic, so they live here.
if [[ -n "$WILL_TOPIC" ]]; then
  args+=( --will-topic "$WILL_TOPIC" )
  [[ -n "$WILL_PAYLOAD" ]] && args+=( --will-payload "$WILL_PAYLOAD" )
  args+=( --will-qos "$WILL_QOS" )
  [[ "$WILL_RETAIN" == "true" ]] && args+=( --will-retain )
  # WILL-level MQTT 5 properties.
  [[ -n "$WILL_DELAY"        ]] && args+=( -D WILL will-delay-interval "$WILL_DELAY" )
  [[ -n "$WILL_MSG_EXPIRY"   ]] && args+=( -D WILL message-expiry-interval "$WILL_MSG_EXPIRY" )
  [[ -n "$WILL_CONTENT_TYPE" ]] && args+=( -D WILL content-type "$WILL_CONTENT_TYPE" )
  [[ -n "$WILL_UPROP_KEY"    ]] && args+=( -D WILL user-property "$WILL_UPROP_KEY" "$WILL_UPROP_VAL" )
fi
if [[ "$MODE" == "pub" ]]; then
  args+=( -m "$MESSAGE" )
[[ "$RETAIN" == "true" ]] && args+=( -r )
fi
# ---- Go ---------------------------------------------------------------------
echo "Running: $BIN ${args[*]}" >&2
exec "$BIN" "${args[@]}"