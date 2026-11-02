Fish relay deployed November 1, 2026

Public endpoint ws://40.160.53.64:42067/
Health endpoint http://40.160.53.64:42067/health
Source /home/kit/fishing-work/relay in default sandbox.
Deployment /srv/fishrelay on debian@40.160.53.64, container fishrelay-relay-1.
Docker Compose restart unless-stopped. Restart with cd /srv/fishrelay && sudo docker compose up -d --build.
No sandbox daemon required, no host firewall changes necessary.

Only JSON text frames, connect to /.
Host sends {"op":"host"}, receives {"op":"hosted","code":"12-HEX-CHARS"}.
Visitor sends {"op":"join","code":"...","name":"Zach","fish":{"data":"res://data/fish/goldfish.tres","fullness":0.75}}.
Visitor receives {"op":"joined","id":"UUID"}.
Host receives {"op":"arrival","id":"UUID","name":"Zach","fish":{"data":"...","fullness":0.75}}.
Name strips controls, trims and truncates to 32 Unicode characters, fallback Visitor.
Fish data is a nonempty string up to 256 code units; fullness is finite 0..1.
Host sends {"op":"send","to":"UUID","body":{"op":"snapshot"}} to one visitor.
Host sends {"op":"broadcast","body":{"op":"snapshot"}} to all visitors.
Visitors receive body directly without an envelope.
Visitor sends {"op":"send","body":{"op":"feed"}}.
Host receives {"op":"message","id":"UUID","body":{"op":"feed"}}.
Visitor disconnect gives host {"op":"departure","id":"UUID"}.
Host disconnect gives visitors {"op":"closed"}, then close 1000 host_closed.
Errors are {"op":"error","code":"bad_code"} etc, normally keep socket open.
Binary closes 1003. Oversize closes 1009. Rate closes 1008 rate_limit.
Codes case-insensitive, 12 random hex characters; visitor IDs UUID strings.
One role/room per socket; reconnect to switch. No persistence/reconnect token.
Host is authoritative; opaque body objects MUST be validated by the game.

Bounds 8 visitors/room, 128 rooms total, 1152 sockets total, 64 concurrent sockets/IP.
65536 bytes maximum incoming/outgoing JSON; 40 incoming messages/rolling second/socket.
Visitor->host envelope adds bytes, so near-limit payload may return delivery_failed.
Outgoing buffer 256KiB/socket, slow receiver closes 1013.
10-second host/join deadline; 30-second heartbeat, missed pong terminates.
No TLS/account authentication. Room code is the invite secret.
Do not send private information or trust a visitor's claimed identity/state.
No game files changed.

npm ci then npm test against a running localhost:3000 instance.
RELAY_URL=ws://40.160.53.64:42067/ npm test tests public deployment.
Local and public tests PASS host/join, 8 visitors cap, name cap, bad codes/JSON/fish,
targeted/broadcast forwarding, visitor->host, isolation, forbidden broadcast,
departure, host close cleanup, 64KiB cap, binary rejection and 40/s limit.

Public discovery: clients send {"op":"list"} on a separate lobby WebSocket.
The relay replies {"op":"rooms","rooms":[{"code":"…","name":"Player","fish_count":1,"visitor_count":0}]}.
Internal IDs remain transport-only; players never enter or share them.
Host requests include name (sanitized, max 24) and fish_count. Snapshots update the owned fish count.
Listings poll every two seconds and disappear on host disconnect. Existing limits remain 128 rooms and eight visitors each.
Production supports WSS /relay and legacy desktop WS port 42067. Source and compose are in scripts/relay.
