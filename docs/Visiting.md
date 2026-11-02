# Visiting tanks
Use Visit tanks while playing. Set your name, open your tank and share its room code privately. A friend enters the code and chooses one owned fish to bring. Neither player needs port forwarding. Both need the same game/catalog version.

The host simulates all fish and pellets. Snapshots arrive about ten times per second; visitors interpolate visual sprites, never run a second economy. The visitor's original fish, food and positions remain frozen and saved locally. Host pause stops simulation and rejects feeding; visitor pause blocks their local feeding but networking continues. Leave or a lost connection restores the visitor's tank. Closing a host room removes visiting fish, never owned or gifted fish.

Clicking the host's water drops food there. A host fish eating visitor food pays the host normally and gives the feeder a rounded 20 percent tip. A visiting fish eating any food pays its visitor, not the host. Earnings update the visitor's own money and save immediately. Visitor fish are excluded from host saves; shop purchases are blocked while visiting.

Gift brought fish opens a permanent-transfer confirmation. The donor first saves removal with a durable outbox; the host saves the new owned fish and a unique receipt before acknowledging. Retries reuse the receipt, avoiding duplicate gifts. A lost acknowledgment leaves a pending gift saved, not refunded. Revisit the same host's room (even with no fish left) to complete delivery. The outbox is bound to the host's saved tank identity, not the temporary room code. A host save failure leaves the transfer pending. This is friend-to-friend local-save persistence, not a server-account inventory or anti-cheat system.

Player names are capped at 24 characters and stored in the version-1 save alongside money and fish. Existing saves load with Player as the default. Net.gd owns transport and room state; VisitMenu owns controls; Tank only forwards visitor clicks and tags food. Fish hands payout attribution to Net, which uses the existing event bus for ordinary single-player earnings.

The relay is plaintext and room-code protected, not authenticated. Share codes privately, not in public posts. Do not send secrets. Only shipped FishData catalog paths may be loaded from peer messages; no scripts or arbitrary resources are accepted. Internet-hosted or adversarial play would need TLS, accounts, stronger economy validation, and server-side durable transfer storage.

See Relay.md for service deployment/protocol. The default endpoint is ws://40.160.53.64:42067/.
