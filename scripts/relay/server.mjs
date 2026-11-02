import { createServer } from 'node:http';
import { randomBytes, randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import WebSocket, { WebSocketServer } from 'ws';

const MAX_BYTES = 64 * 1024;
const MAX_ROOMS = 128;
const MAX_CLIENTS = MAX_ROOMS * 9;
const rooms = new Map();
const ips = new Map();
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const http = createServer((req, res) => {
  res.writeHead(req.url === '/health' ? 200 : 404, { 'content-type': 'application/json' });
  res.end(JSON.stringify(req.url === '/health' ? { ok: true } : { error: 'not_found' }));
});
http.headersTimeout = 5000;
http.requestTimeout = 5000;
const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_BYTES, perMessageDeflate: false });
function close(ws, code = 1008, reason = 'policy') {
  if (ws.readyState >= WebSocket.CLOSING) return;
  ws.close(code, reason);
  const timer = setTimeout(() => ws.terminate(), 2000);
  timer.unref();
  ws.once('close', () => clearTimeout(timer));
}
function send(ws, value) {
  if (ws.readyState !== WebSocket.OPEN) return false;
  const text = JSON.stringify(value);
  if (Buffer.byteLength(text) > MAX_BYTES) return false;
  if (ws.bufferedAmount + Buffer.byteLength(text) > 256 * 1024) {
    close(ws, 1013, 'slow_receiver');
    return false;
  }
  ws.send(text, error => { if (error) ws.terminate(); });
  return true;
}
const cleanName = value => Array.from(String(value ?? '').replace(/[\x00-\x1f\x7f]/g, '').trim()).slice(0, 24).join('') || 'Player';
const cleanCount = value => Number.isInteger(value) ? Math.max(0, Math.min(10000, value)) : 0;
const error = (ws, code) => send(ws, { op: 'error', code });
http.on('upgrade', (req, socket, head) => {
  socket.on('error', () => {});
  const ip = req.socket.remoteAddress;
  if (req.url !== '/' || wss.clients.size >= MAX_CLIENTS || (ips.get(ip) || 0) >= 64) {
    socket.end('HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n');
    return;
  }
  wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req));
});
wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  ips.set(ip, (ips.get(ip) || 0) + 1);
  ws.alive = true;
  ws.role = null;
  ws.room = null;
  ws.times = [];
  const handshake = setTimeout(() => close(ws, 1008, 'handshake_timeout'), 10000);
  handshake.unref();
  ws.on('error', () => {});
  ws.on('pong', () => { ws.alive = true; });
  ws.on('message', (raw, binary) => {
    if (ws.readyState !== WebSocket.OPEN) return;
    const now = performance.now();
    ws.times = ws.times.filter(time => now - time < 1000);
    if (ws.times.length >= 40) return close(ws, 1008, 'rate_limit');
    ws.times.push(now);
    if (binary) return close(ws, 1003, 'text_json_only');
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return error(ws, 'bad_json'); }
    if (!object(msg) || typeof msg.op !== 'string') return error(ws, 'bad_message');
    if (msg.op === 'list') {
      clearTimeout(handshake);
      return send(ws, { op: 'rooms', rooms: [...rooms.values()].filter(r => r.host.readyState === WebSocket.OPEN).map(r => ({
        code: r.code, name: r.name, fish_count: r.fishCount, visitor_count: r.visitors.size
      })) });
    }
    if (msg.op === 'host') {
      if (ws.role) return error(ws, 'already_in_room');
      if (rooms.size >= MAX_ROOMS) return error(ws, 'server_full');
      let code;
      do { code = randomBytes(6).toString('hex').toUpperCase(); } while (rooms.has(code));
      const room = { code, host: ws, visitors: new Map(), name: cleanName(msg.name), fishCount: cleanCount(msg.fish_count) };
      rooms.set(code, room);
      ws.role = 'host';
      ws.room = room;
      clearTimeout(handshake);
      return send(ws, { op: 'hosted', code });
    }
    if (msg.op === 'join') {
      if (ws.role) return error(ws, 'already_in_room');
      if (typeof msg.code !== 'string' || !/^[A-Fa-f0-9]{12}$/.test(msg.code)) return error(ws, 'bad_code');
      const room = rooms.get(msg.code.toUpperCase());
      if (!room || room.host.readyState !== WebSocket.OPEN) return error(ws, 'room_not_found');
      if (room.visitors.size >= 8) return error(ws, 'room_full');
      if (typeof msg.name !== 'string' || !object(msg.fish) ||
          typeof msg.fish.data !== 'string' || !msg.fish.data.length || msg.fish.data.length > 256 ||
          !Number.isFinite(msg.fish.fullness) || msg.fish.fullness < 0 || msg.fish.fullness > 1) {
        return error(ws, 'bad_join');
      }
      const name = Array.from(msg.name.replace(/[\x00-\x1f\x7f]/g, '').trim()).slice(0, 32).join('') || 'Visitor';
      const tier = msg.fish.tier ?? 0;
      if (!Number.isInteger(tier) || tier < 0 || tier > 3) return error(ws, 'bad_join');
      const fish = { data: msg.fish.data, fullness: msg.fish.fullness, tier };
      ws.id = randomUUID();
      ws.role = 'visitor';
      ws.room = room;
      room.visitors.set(ws.id, ws);
      clearTimeout(handshake);
      send(ws, { op: 'joined', id: ws.id });
      return send(room.host, { op: 'arrival', id: ws.id, name, fish });
    }
    if (!ws.role) return error(ws, 'not_in_room');
    if ((msg.op !== 'send' && msg.op !== 'broadcast') || !object(msg.body)) return error(ws, 'bad_message');
    const room = ws.room;
    if (ws.role === 'host') {
      if (msg.op === 'broadcast') {
        if (msg.body.op === 'snapshot' && Array.isArray(msg.body.fish)) {
          room.fishCount = cleanCount(msg.body.fish.filter(f => object(f) && !f.name).length);
        }
        for (const visitor of room.visitors.values()) send(visitor, msg.body);
        return;
      }
      const target = room.visitors.get(msg.to);
      if (!target) return error(ws, 'visitor_not_found');
      return send(target, msg.body);
    }
    if (msg.op !== 'send') return error(ws, 'forbidden');
    if (!send(room.host, { op: 'message', id: ws.id, body: msg.body })) error(ws, 'delivery_failed');
  });
  ws.on('close', () => {
    clearTimeout(handshake);
    const count = ips.get(ip) - 1;
    if (count) ips.set(ip, count); else ips.delete(ip);
    const room = ws.room;
    if (!room) return;
    if (ws.role === 'host') {
      rooms.delete(room.code);
      for (const visitor of room.visitors.values()) {
        visitor.room = null;
        send(visitor, { op: 'closed' });
        close(visitor, 1000, 'host_closed');
      }
      room.visitors.clear();
    } else {
      room.visitors.delete(ws.id);
      send(room.host, { op: 'departure', id: ws.id });
    }
    ws.room = null;
  });
});
const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.alive) { ws.terminate(); continue; }
    ws.alive = false;
    if (ws.readyState === WebSocket.OPEN) ws.ping();
  }
}, 30000);
heartbeat.unref();
http.listen(Number(process.env.PORT || 3000), '0.0.0.0', () => console.log('fishrelay listening', http.address().port));
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    clearInterval(heartbeat);
    for (const ws of wss.clients) {
      send(ws, { op: 'closed' });
      close(ws, 1001, 'server_shutdown');
    }
    http.close();
    const timer = setTimeout(() => process.exit(0), 2500);
    timer.unref();
  });
}
