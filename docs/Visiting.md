# Visiting tanks
Use Visit tanks while playing. Log in and open your tank to list it publicly. Visitors see host names, fish counts and visitor counts refreshed every two seconds. Click Join beside a tank, choose one owned fish and visit. Rooms disappear when the host disconnects. Neither player needs port forwarding. Both need the same game/catalog version.

The host simulates all fish and pellets. Snapshots arrive about ten times per second; visitors interpolate visual sprites, never run a second economy. The visitor's original fish, food and positions remain frozen and saved locally. Host pause stops simulation and rejects feeding; visitor pause blocks their local feeding but networking continues. Leave or a lost connection restores the visitor's tank. Closing a host room removes visiting fish, never owned or gifted fish.

Clicking the host's water drops food there. A host fish eating visitor food pays the host normally and gives the feeder a rounded 20 percent tip. A visiting fish eating any food pays its visitor, not the host. Earnings update the visitor's own money and save immediately. Visitor fish are excluded from host saves; shop purchases are blocked while visiting.

Gift brought fish opens a permanent-transfer confirmation. You must keep at least one fish at home. The account server validates ownership and commits the transfer atomically to both cloud saves. A disconnect cannot undo a committed gift, and repeated transfer IDs cannot duplicate it. Your brought fish keeps its tier. See Accounts.md for cloud cache and account details.

Names come from your signed-in account and cannot be changed or spoofed through the visit panel. Open tanks are publicly listed to signed-in players. Both desktop and web use HTTPS/WSS. The relay caps rooms at 128 and visitors at eight per tank. Only shipped FishData resources are loaded from peer messages; no arbitrary resources or scripts.

See Relay.md for service deployment/protocol. The default endpoint is wss://fish.40-160-53-64.sslip.io/relay.

Brought and gifted fish retain tier. Relay arrival preserves optional tier (default 0) validated as integer 0..3. Snapshots carry tier for visual scale/tint.
