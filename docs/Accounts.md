# Accounts and cloud saves

Choose Enter your aquarium, then sign up or log in. Usernames are case-insensitive, 3–16 letters, digits or underscores. Passwords are never stored in plaintext. Remember me keeps a session token on this device, not the password. Use Switch account on the title to clear it. Do not use Remember me on a shared computer.

Desktop and web use the same HTTPS account service and secure WebSocket relay. Your cloud save follows your account. Existing local progress is migrated when you create your first account. Each account has its own local cache. If the service is unavailable, an existing account cache can still be played offline. On login the newer saved_at wins, subject to server gift ownership protections. Avoid playing the same account simultaneously on multiple devices; this is newest-save synchronization, not a shared live tank.

No email address is collected. There is no self-service password reset. Password reset is manual by the server administrator. Keep your password somewhere safe.

Gifts are committed by the account server in one SQLite transaction. It verifies the donor owns the fish and retains at least one other fish, removes it from the donor cloud save and adds it to the recipient cloud save. Transaction IDs are idempotent. Gift ownership records prevent old local saves from resurrecting a gifted fish or removing an incoming gift. The UI also disables gifting your last fish.

The host still simulates feeding and payouts. This is a small friend-oriented idle game, not a competitive anti-cheat economy. Server-validated gifts do not make every offline/client-earned dollar authoritative.

The account database lives in the relay service's persistent volume. Back it up separately from the source repository. Session tokens and the database must never be committed. Production endpoints use HTTPS/WSS only.
