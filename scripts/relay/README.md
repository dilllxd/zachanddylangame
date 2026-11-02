# Aquarium accounts and relay

Node 24, SQLite and bcryptjs. Run `npm ci && npm test`. Deploy with `docker compose up -d --build`; never delete the `accounts` volume. SQLite lives at `/data/accounts.sqlite`, with WAL and full synchronous writes. Back up using SQLite's backup API rather than copying an active database without its WAL. The public endpoint is `https://fish.40-160-53-64.sslip.io`; WebSocket is `wss://fish.40-160-53-64.sslip.io/relay`. Port 42067 is loopback-only. Nginx proxies `/api/` and `/relay`, rejects no origins itself, and supplies trusted real client IPs. The application rejects browser Origins other than PUBLIC_ORIGIN; native clients may omit Origin.

## HTTP

Send JSON. Authenticated calls need `Authorization: Bearer TOKEN`. Errors are `{error: "code"}` with a non-2xx status. Signup/login are rate-limited per IP and case-insensitive username.

`POST /api/signup {username,password,save}` and `POST /api/login {username,password}` return `{token,username,save}`. Omit signup save or pass `{}` to seed Goldy. Username is 3-16 ASCII letters/digits/underscores, case-insensitively unique; password is 8-128 characters. Passwords use domain-separated SHA-256 before bcrypt cost 12, avoiding bcrypt's 72-byte truncation. Sessions are random 32-byte tokens, only SHA-256 hashes stored, expiring after 30 days.

`GET /api/me` returns `{username}`. `GET /api/save` and `PUT /api/save {save}` return `{save}`. `POST /api/gift {to,fish_id,transfer_id}` returns the giver's `{save}`.

A save has version 1, nonnegative money, saved_at in Unix seconds, and at least one fish. Fish are `{id,data,tier,fullness,position}`, with a stable 32-lowercase-hex id, shipped resource path, tier 0-3, fullness 0-1 and two-number position. Extra game fields are preserved. The server supplies `server_revision`. Always apply the canonical response and carry that revision into subsequent uploads. Newest saved_at wins, with incoming-gift protection and donor ownership tombstones. A stale client cannot erase unseen incoming gifts or restore gifted fish. A client that has acknowledged a gift's revision may intentionally consume that fish through merging.

Gift transfers are atomic, validate current donor ownership, preserve at least one donor fish, and are idempotent by donor plus 32-hex transfer_id. A reused transfer_id with a different target/fish is rejected. This is cloud storage and ownership protection, not server-authoritative economy/anti-cheat.

## WebSocket

Every client message includes token, including list/send/broadcast. Identity is bound to the token, never client name. Existing room messages remain supported. `{op:"join",code,fish_id,token}` or fish.id must identify an owned cloud fish; arrival contains its canonical record and account name.

A visiting client sends `{op:"gift",fish_id,transfer_id,token}` to gift its visiting fish to the current host. Host receives `{op:"gift_received",fish,transfer_id,save}`, where save is the recipient's canonical cloud save including server_revision. Giver receives `{op:"gift_sent",fish_id,transfer_id,save}` with its canonical save. Cache/apply the recipient save before allowing merge/consumption of the gifted fish. Retry returns giver acknowledgment without duplicating recipient events or fish. HTTP gifts also notify connected recipient hosts. Forwarded body gift/gift_ack and other reserved server events are blocked.

## Manual password reset

There is no email recovery or public reset endpoint. An administrator with SSH access can reset a known username on the server. This preserves the save and invalidates all existing sessions. Replace ACCOUNT_NAME; the command generates and prints a temporary password once. Deliver it privately.

```sh
cd /srv/fishrelay
docker compose exec -T relay node --input-type=module - ACCOUNT_NAME <<'JS'
import { DatabaseSync } from 'node:sqlite';
import { randomBytes, createHash } from 'node:crypto';
import bcrypt from 'bcryptjs';
const db = new DatabaseSync('/data/accounts.sqlite');
const user = db.prepare('SELECT id,username FROM users WHERE key=?')
  .get(process.argv[2].toLowerCase());
if (!user) throw Error('Account not found');
const password = randomBytes(18).toString('base64url');
const prehash = createHash('sha256')
  .update('fishingidle-password-v1\0' + password).digest('hex');
const hash = await bcrypt.hash(prehash, 12);
db.exec('BEGIN IMMEDIATE');
try {
  db.prepare('UPDATE users SET password=? WHERE id=?').run(hash, user.id);
  db.prepare('DELETE FROM sessions WHERE uid=?').run(user.id);
  db.exec('COMMIT');
} catch (error) {
  db.exec('ROLLBACK');
  throw error;
}
db.close();
console.log(user.username + ' temporary password: ' + password);
JS
```
