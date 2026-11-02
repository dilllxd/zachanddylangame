import { createServer } from 'node:http';
import { randomBytes, randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import WebSocket, { WebSocketServer } from 'ws';
import { Accounts, fail } from './accounts.mjs';

const MAX_BYTES = 64 * 1024;
const MAX_ROOMS = 128;
const MAX_CLIENTS = MAX_ROOMS * 9;
const rooms = new Map();
const ips = new Map();
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const accounts = new Accounts(process.env.DB_PATH || '/data/accounts.sqlite');
const origin = process.env.PUBLIC_ORIGIN || 'https://fish.40-160-53-64.sslip.io';
const allowedOrigin = req => !req.headers.origin || req.headers.origin === origin;
const limits = new Map();
let authActive=0;
function rate(key, limit, window=600000) {
  const now=Date.now();
  const bucket=limits.get(key);
  if (!bucket || bucket.until < now) { limits.set(key,{count:1,until:now+window}); return; }
  if (++bucket.count > limit) fail('rate_limit',429);
}
const cleanup=setInterval(()=>{for(const [k,v] of limits) if(v.until<Date.now()) limits.delete(k)},60000);
cleanup.unref();
const clientIp = req => process.env.TRUST_PROXY === '1' ? (req.headers['x-real-ip'] || req.socket.remoteAddress) : req.socket.remoteAddress;
async function body(req) {
  if (!String(req.headers['content-type'] || '').toLowerCase().startsWith('application/json')) fail('json_required',415);
  const chunks=[]; let bytes=0;
  for await (const chunk of req) { bytes+=chunk.length; if(bytes>1024*1024) fail('body_too_large',413); chunks.push(chunk); }
  try { const v=JSON.parse(Buffer.concat(chunks).toString()); if(!object(v)) fail('bad_json'); return v; }
  catch { fail('bad_json'); }
}
function notifyGift(donor,result,transferId) {
  if(result.duplicate) return;
  for(const peer of wss.clients) {
    if(peer.user?.id === result.recipient && peer.role==='host')
      send(peer,{op:'gift_received',fish:result.fish,transfer_id:transferId,save:result.recipientSave});
  }
}
const http = createServer(async (req, res) => {
  res.setHeader('content-type','application/json');
  res.setHeader('cache-control','no-store');
  res.setHeader('x-content-type-options','nosniff');
  const reply=(status,value)=>{res.writeHead(status);res.end(JSON.stringify(value))};
  try {
    if(!allowedOrigin(req)) fail('origin_forbidden',403);
    const path=new URL(req.url,'http://localhost').pathname;
    if(path==='/health') return reply(200,{ok:true});
    if(!path.startsWith('/api/')) return reply(404,{error:'not_found'});
    rate('http:'+clientIp(req),600,60000);
    if(req.method==='POST' && (path==='/api/signup'||path==='/api/login')) {
      const data=await body(req);
      rate('auth-ip:'+clientIp(req),30);
      rate('auth-name:'+String(data.username).toLowerCase(),20);
      if(authActive>=4) fail('auth_busy',429);
      authActive++;
      try {
        const value=path==='/api/signup' ? await accounts.signup(data.username,data.password,data.save) : await accounts.login(data.username,data.password);
        return reply(200,value);
      } finally { authActive--; }
    }
    const user=accounts.authenticate(String(req.headers.authorization||'').replace(/^Bearer /,''));
    if(req.method==='GET' && path==='/api/me') return reply(200,{username:user.username});
    if(req.method==='GET' && path==='/api/save') return reply(200,{save:accounts.save(user.id)});
    if(req.method==='PUT' && path==='/api/save') {
      const data=await body(req);
      return reply(200,{save:accounts.upload(user.id,data.save)});
    }
    if(req.method==='POST' && path==='/api/gift') {
      const data=await body(req);
      const result=accounts.gift(user.id,data.to,data.fish_id,data.transfer_id);
      notifyGift(user.id,result,data.transfer_id);
      return reply(200,{save:result.save});
    }
    reply(404,{error:'not_found'});
  } catch(e) { if(!e.status) console.error('http error',e); reply(e.status||500,{error:e.status?e.message:'internal_error'}); }
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
  const ip = clientIp(req);
  if (!allowedOrigin(req) || !['/','/relay'].includes(new URL(req.url, 'http://localhost').pathname) || wss.clients.size >= MAX_CLIENTS || (ips.get(ip) || 0) >= 64) {
    socket.end('HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n');
    return;
  }
  wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req));
});
wss.on('connection', (ws, req) => {
  const ip = clientIp(req);
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
    let user;
    try {
      user=accounts.authenticate(msg.token);
      if(ws.user && ws.user.id!==user.id) return error(ws,'identity_changed');
      ws.user=user;
    } catch { return error(ws,'unauthorized'); }
    if(msg.op==='gift') {
      if(ws.role!=='visitor' || !ws.room) return error(ws,'not_visiting');
      try {
        if (msg.fish_id !== ws.fishId) return error(ws,'fish_not_visiting');
        const result=accounts.gift(user.id,ws.room.host.user.username,msg.fish_id,msg.transfer_id);
        notifyGift(user.id,result,msg.transfer_id);
        send(ws,{op:'gift_sent',fish_id:msg.fish_id,transfer_id:msg.transfer_id,save:result.save});
      } catch(e) { error(ws,e.status?e.message:'internal_error'); }
      return;
    }
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
      const room = { code, host: ws, visitors: new Map(), name: user.username, fishCount: accounts.save(user.id).fish.length };
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
      if(room.host.user.id === user.id) return error(ws,'cannot_visit_self');
      const fishId=msg.fish_id ?? msg.fish?.id;
      const fish=accounts.save(user.id).fish.find(f=>f.id===fishId);
      if(!fish) return error(ws,'fish_not_owned');
      ws.fishId=fishId;
      const name=user.username;
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
    if(['gift','gift_ack','gift_received','gift_sent','arrival','joined','hosted','message','closed','departure','rooms'].includes(msg.body.op)) return error(ws,'reserved_operation');
    if (ws.role === 'host') {
      if (msg.op === 'broadcast') {
        if (msg.body.op === 'snapshot' && Array.isArray(msg.body.fish)) {
          room.fishCount = accounts.save(user.id).fish.length;
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
