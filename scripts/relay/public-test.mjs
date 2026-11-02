import WebSocket from 'ws';
import assert from 'node:assert/strict';
const url='wss://fish.40-160-53-64.sslip.io/relay';
async function client(){const w=new WebSocket(url); await new Promise((r,j)=>{w.once('open',r);w.once('error',j)});return w;}
function request(w,m){return new Promise((r,j)=>{let t=setTimeout(()=>j(Error('timeout')),5000);w.once('message',b=>{clearTimeout(t);r(JSON.parse(b))});w.send(JSON.stringify(m))})}
const h=await client(), b=await client();
const hosted=await request(h,{op:'host',name:'x'.repeat(80),fish_count:3});
let list=await request(b,{op:'list'});
let room=list.rooms.find(r=>r.code===hosted.code);
assert.equal(room.name.length,24);assert.equal(room.fish_count,3);assert.equal(room.visitor_count,0);
await new Promise(r=>{h.once('close',r);h.close()});
list=await request(b,{op:'list'});
assert(!list.rooms.some(r=>r.code===hosted.code));
b.close();console.log('PASS WSS public listing, name cap, counts, host close removal');
