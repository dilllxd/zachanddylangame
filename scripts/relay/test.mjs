import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import WebSocket from 'ws';
import { Accounts } from './accounts.mjs';
const dir=mkdtempSync(tmpdir()+'/fishaccounts-');
const fish=n=>({id:n.toString(16).padStart(32,'0'),data:'res://data/fish/goldfish.tres',tier:0,fullness:1,position:[400,300]});
const save=(ids,time=100)=>({version:1,money:20,saved_at:time,fish:ids.map(fish)});
const db=new Accounts(dir+'/unit.sqlite');
const a=await db.signup('Alpha','password-long',save([1,2,3]));
const b=await db.signup('Beta','password-long',save([4]));
assert.equal((await db.login('ALPHA','password-long')).username,'Alpha');
await assert.rejects(()=>db.signup('alpha','password-long',save([6])),/username_taken/);
await assert.rejects(()=>db.login('Alpha','wrongpass'),/invalid_credentials/);
assert.throws(()=>db.authenticate('0'.repeat(64)),/unauthorized/);
const uid=db.authenticate(a.token).id, bid=db.authenticate(b.token).id;
assert.equal(db.upload(uid,save([1,2,3],99)).money,20);
const t='a'.repeat(32);
const gift=db.gift(uid,'beta',fish(2).id,t);
assert.equal(gift.save.fish.length,2);
assert.equal(db.gift(uid,'Beta',fish(2).id,t).duplicate,true);
assert.equal(db.save(bid).fish.length,2);
assert.throws(()=>db.gift(uid,'Beta',fish(3).id,t),/transfer_conflict/);
assert.equal(db.upload(uid,save([1,2,3],101)).fish.length,2,'tombstone rejects resurrection');
assert.equal(db.upload(bid,save([4],102)).fish.length,2,'stale incoming omission preserved');
db.gift(uid,'Beta',fish(3).id,'b'.repeat(32));
assert.throws(()=>db.gift(uid,'Beta',fish(1).id,'c'.repeat(32)),/must_keep_one_fish/);
assert.throws(()=>db.gift(uid,'Beta',fish(4).id,'c'.repeat(32)),/fish_not_owned/);
assert.equal(db.save(uid).fish.length,1);
assert.equal(db.save(bid).fish.length,3);
const long='a'.repeat(100)+'x';
const c=await db.signup('LongPassword',long,{});
await assert.rejects(()=>db.login('LongPassword','a'.repeat(100)+'y'),/invalid_credentials/);
assert.equal((await db.login('LongPassword',long)).username,'LongPassword');
db.db.prepare('UPDATE sessions SET expires=0 WHERE uid=?').run(db.authenticate(c.token).id);
assert.throws(()=>db.authenticate(c.token),/unauthorized/);
db.db.close();
const reopened=new Accounts(dir+'/unit.sqlite');
assert.equal(reopened.save(bid).fish.length,3,'durable after restart');
reopened.db.close();
console.log('PASS accounts hashing/case/expiry/save LWW/tombstones/incoming/last fish/atomic/idempotent/durability');
const process=spawn('node',['server.mjs'],{cwd:import.meta.dirname,env:{...globalThis.process.env,PORT:'0',DB_PATH:dir+'/http.sqlite'},stdio:['ignore','pipe','inherit']});
const port=await new Promise((resolve,reject)=>{process.stdout.on('data',b=>{const m=b.toString().match(/listening (\d+)/);if(m) resolve(m[1]);});process.once('exit',()=>reject(Error('server exited')))});
const base='http://127.0.0.1:'+port;
const api=async(path,method='GET',body,token,origin)=>{
 const r=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{}),...(origin?{origin}:{})},...(body?{body:JSON.stringify(body)}:{})});
 return {status:r.status,...await r.json()};
};
const host=await api('/api/signup','POST',{username:'HostUser',password:'password-long',save:save([10])});
const guest=await api('/api/signup','POST',{username:'GuestUser',password:'password-long',save:save([11,12,13])});
assert.equal(host.status,200);assert.equal(guest.status,200);
assert.equal((await api('/api/me','GET',null,host.token)).username,'HostUser');
assert.equal((await api('/api/me','GET',null,undefined)).status,401);
assert.equal((await api('/api/login','POST',{username:'hostuser',password:'password-long'})).status,200);
assert.equal((await api('/api/me','GET',null,host.token,'https://evil.invalid')).status,403);
assert.equal((await api('/api/save','PUT',{save:save([10],101)},host.token)).save.fish.length,1);
const sockets=[];
async function client(token) {
 const ws=new WebSocket(base.replace('http','ws')+'/?unused=1');sockets.push(ws);
 await new Promise((r,j)=>{ws.once('open',r);ws.once('error',j)});
 ws.messages=[];ws.on('message',raw=>ws.messages.push(JSON.parse(raw)));
 ws.token=token;return ws;
}
function next(ws,op) {
 return new Promise((resolve,reject)=>{
  const take=()=>{const n=ws.messages.findIndex(m=>m.op===op);if(n>=0){cleanup();resolve(ws.messages.splice(n,1)[0]);}};
  const listener=()=>take();
  const timer=setTimeout(()=>{cleanup();reject(Error('timeout '+op+' '+JSON.stringify(ws.messages)))},5000);
  const cleanup=()=>{clearTimeout(timer);ws.off('message',listener)};
  ws.on('message',listener);take();
 });
}
const send=(ws,m)=>ws.send(JSON.stringify({token:ws.token,...m}));
try {
 const h=await client(host.token),g=await client(guest.token),bad=await client();
 send(bad,{op:'list'});assert.equal((await next(bad,'error')).code,'unauthorized');
 send(h,{op:'host',name:'Spoof'});const room=await next(h,'hosted');
 send(g,{op:'list'});const rooms=await next(g,'rooms');assert.equal(rooms.rooms[0].name,'HostUser');
 send(g,{op:'join',code:room.code,fish:{id:fish(11).id,tier:3},name:'Spoof'});
 await next(g,'joined');const arrival=await next(h,'arrival');assert.equal(arrival.name,'GuestUser');assert.equal(arrival.fish.id,fish(11).id);assert.equal(arrival.fish.tier,0);
 send(g,{op:'send',body:{op:'gift',transfer:{}}});assert.equal((await next(g,'error')).code,'reserved_operation');
 send(h,{op:'send',to:arrival.id,body:{op:'gift_ack'}});assert.equal((await next(h,'error')).code,'reserved_operation');
 send(g,{op:'gift',fish_id:fish(11).id,transfer_id:'f'.repeat(32)});
 const received=await next(h,'gift_received'),sent=await next(g,'gift_sent');
 assert.equal(received.fish.id,fish(11).id);assert.equal(received.save.fish.length,2);assert(received.save.server_revision > 0);assert.equal(sent.save.fish.length,2);
 send(g,{op:'gift',fish_id:fish(11).id,transfer_id:'f'.repeat(32)});
 assert.equal((await next(g,'gift_sent')).save.fish.length,2);
 assert.equal((await api('/api/save','GET',null,host.token)).save.fish.length,2);
 const stale=await api('/api/save','PUT',{save:save([10],200)},host.token);
 assert.equal(stale.save.fish.length,2);
 const staleG=await api('/api/save','PUT',{save:save([11,12,13],201)},guest.token);
 assert.equal(staleG.save.fish.length,2);
 const direct=await api('/api/gift','POST',{to:'HostUser',fish_id:fish(12).id,transfer_id:'e'.repeat(32)},guest.token);
 assert.equal(direct.save.fish.length,1);
 assert.equal((await next(h,'gift_received')).fish.id,fish(12).id);
 const denied=await api('/api/gift','POST',{to:'HostUser',fish_id:fish(13).id,transfer_id:'d'.repeat(32)},guest.token);
 assert.equal(denied.error,'must_keep_one_fish');
 for(let i=0;i<21;i++) {
  const result=await api('/api/login','POST',{username:'NoUser',password:'password-long'});
  if(i===20) assert.equal(result.status,429);
 }
 console.log('PASS HTTP auth/save/origin/rate-limit and actual WS authenticated list/identity/owned join/atomic gifts/reserved forwarding');
} finally {
 for(const ws of sockets) ws.terminate();
 process.kill('SIGTERM');
 await new Promise(r=>process.once('exit',r));
 rmSync(dir,{recursive:true,force:true});
}
