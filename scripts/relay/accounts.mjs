import { DatabaseSync } from 'node:sqlite';
import { randomBytes, createHash } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
export function fail(code, status = 400) { throw Object.assign(new Error(code), { status }); }
const digest = s => createHash('sha256').update(s).digest('hex');
const passwordInput = s => digest('fishingidle-password-v1\0' + s);
const validId = s => typeof s === 'string' && /^[a-f0-9]{32}$/.test(s);
const usernameKey = s => typeof s === 'string' && /^[A-Za-z0-9_]{3,16}$/.test(s) ? s.toLowerCase() : fail('invalid_username');
const validatePassword = s => { if (typeof s !== 'string' || s.length < 8 || s.length > 128) fail('invalid_password'); };
export function normalizeSave(value) {
  if (!object(value) || !Array.isArray(value.fish) || value.fish.length < 1 || value.fish.length > 1000 ||
      !Number.isFinite(value.money) || value.money < 0 || value.money > Number.MAX_SAFE_INTEGER ||
      !Number.isFinite(value.saved_at) || value.saved_at < 0 || value.saved_at > Date.now()/1000 + 300) fail('invalid_save');
  const ids = new Set();
  const fish = value.fish.map(f => {
    if (!object(f) || !validId(f.id) || ids.has(f.id) ||
        typeof f.data !== 'string' || !/^res:\/\/data\/fish\/[A-Za-z0-9_-]+\.tres$/.test(f.data) ||
        !Number.isInteger(f.tier ?? 0) || (f.tier ?? 0) < 0 || (f.tier ?? 0) > 3 ||
        !Number.isFinite(f.fullness) || f.fullness < 0 || f.fullness > 1 ||
        !Array.isArray(f.position) || f.position.length !== 2 || !f.position.every(n => Number.isFinite(n) && Math.abs(n) < 100000)) fail('invalid_fish');
    ids.add(f.id);
    return { id:f.id, data:f.data, tier:f.tier ?? 0, fullness:f.fullness, position:f.position };
  });
  return { ...value, version:1, fish };
}
export class Accounts {
  constructor(path) {
    if (path !== ':memory:') mkdirSync(dirname(path), {recursive:true});
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;
      CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, username TEXT NOT NULL, key TEXT UNIQUE NOT NULL, password TEXT NOT NULL, save TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, uid INTEGER NOT NULL REFERENCES users(id), expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS ownership(fish_id TEXT PRIMARY KEY, uid INTEGER NOT NULL REFERENCES users(id));
      CREATE TABLE IF NOT EXISTS incoming(uid INTEGER NOT NULL, fish_id TEXT NOT NULL, revision INTEGER NOT NULL, PRIMARY KEY(uid,fish_id));
      CREATE TABLE IF NOT EXISTS transfers(donor INTEGER NOT NULL, transfer_id TEXT NOT NULL, recipient INTEGER NOT NULL, fish_id TEXT NOT NULL, fish TEXT NOT NULL, PRIMARY KEY(donor,transfer_id));`);
    this.dummy = bcrypt.hashSync(passwordInput('invalid-password'), 12);
  }
  transaction(fn) {
    this.db.exec('BEGIN IMMEDIATE');
    try { const value=fn(); this.db.exec('COMMIT'); return value; }
    catch(e) { this.db.exec('ROLLBACK'); throw e; }
  }
  user(id) { return this.db.prepare('SELECT * FROM users WHERE id=?').get(id); }
  save(id) { return JSON.parse(this.user(id).save); }
  persist(id,save) {
    const revision = this.user(id).revision + 1;
    const result={...save, server_revision:revision};
    this.db.prepare('UPDATE users SET save=?,revision=? WHERE id=?').run(JSON.stringify(result),revision,id);
    return result;
  }
  token(user) {
    const token=randomBytes(32).toString('hex');
    this.db.prepare('DELETE FROM sessions WHERE expires < ?').run(Date.now());
    this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(digest(token),user.id,Date.now()+30*86400000);
    return {token,username:user.username,save:this.save(user.id)};
  }
  authenticate(token) {
    if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) fail('unauthorized',401);
    const user=this.db.prepare('SELECT u.* FROM users u JOIN sessions s ON u.id=s.uid WHERE s.hash=? AND s.expires>?').get(digest(token),Date.now());
    if (!user) fail('unauthorized',401);
    return user;
  }
  async signup(username,password,save) {
    const key=usernameKey(username); validatePassword(password);
    save=normalizeSave((!save || (object(save) && !Object.keys(save).length)) ? {version:1,money:0,saved_at:Math.floor(Date.now()/1000),fish:[{id:randomBytes(16).toString('hex'),data:'res://data/fish/goldfish.tres',tier:0,fullness:1,position:[400,300]}]} : save);
    if (this.db.prepare('SELECT id FROM users WHERE key=?').get(key)) fail('username_taken',409);
    const hash=await bcrypt.hash(passwordInput(password),12);
    return this.transaction(()=>{
      if (this.db.prepare('SELECT id FROM users WHERE key=?').get(key)) fail('username_taken',409);
      for (const f of save.fish) if (this.db.prepare('SELECT uid FROM ownership WHERE fish_id=?').get(f.id)) fail('fish_id_in_use',409);
      const result=this.db.prepare('INSERT INTO users(username,key,password,save) VALUES(?,?,?,?)').run(username,key,hash,JSON.stringify({...save,server_revision:0}));
      const id=Number(result.lastInsertRowid);
      for (const f of save.fish) this.db.prepare('INSERT INTO ownership VALUES(?,?)').run(f.id,id);
      return this.token(this.user(id));
    });
  }
  async login(username,password) {
    const key=usernameKey(username); validatePassword(password);
    const user=this.db.prepare('SELECT * FROM users WHERE key=?').get(key);
    const ok=await bcrypt.compare(passwordInput(password),user?.password ?? this.dummy);
    if (!user || !ok) fail('invalid_credentials',401);
    return this.token(user);
  }
  upload(id,input) {
    const incoming=normalizeSave(input);
    return this.transaction(()=>{
      const current=this.save(id);
      if (incoming.saved_at < current.saved_at) return current;
      const revision=Number.isInteger(incoming.server_revision)?incoming.server_revision:-1;
      incoming.fish=incoming.fish.filter(f=>{
        const owner=this.db.prepare('SELECT uid FROM ownership WHERE fish_id=?').get(f.id);
        return !owner || owner.uid===id;
      });
      // A stale client may not even know an incoming gift exists. Keep it until
      // a save based on the gift's canonical revision explicitly consumes it.
      for (const f of current.fish) {
        const guard=this.db.prepare('SELECT revision FROM incoming WHERE uid=? AND fish_id=?').get(id,f.id);
        if (guard && revision < guard.revision && !incoming.fish.some(x=>x.id===f.id)) incoming.fish.push(f);
      }
      if (!incoming.fish.length) fail('must_keep_one_fish',409);
      for (const f of incoming.fish) this.db.prepare('INSERT OR IGNORE INTO ownership VALUES(?,?)').run(f.id,id);
      // Ownership is retained for removed fish as a permanent tombstone against
      // ID reuse by another account. Gift transfers change its owner atomically.
      this.db.prepare('DELETE FROM incoming WHERE uid=? AND revision<=?').run(id,revision);
      return this.persist(id,incoming);
    });
  }
  gift(donor,to,fishId,transferId) {
    const key=usernameKey(to);
    if (!validId(fishId) || !validId(transferId)) fail('invalid_transfer');
    return this.transaction(()=>{
      const recipient=this.db.prepare('SELECT * FROM users WHERE key=?').get(key);
      if (!recipient) fail('recipient_not_found',404);
      if (recipient.id===donor) fail('cannot_gift_self',409);
      const old=this.db.prepare('SELECT * FROM transfers WHERE donor=? AND transfer_id=?').get(donor,transferId);
      if (old) {
        if (old.recipient!==recipient.id || old.fish_id!==fishId) fail('transfer_conflict',409);
        return {save:this.save(donor),fish:JSON.parse(old.fish),recipient:recipient.id,recipientSave:this.save(recipient.id),duplicate:true};
      }
      const source=this.save(donor), target=this.save(recipient.id);
      const fish=source.fish.find(f=>f.id===fishId);
      const owner=this.db.prepare('SELECT uid FROM ownership WHERE fish_id=?').get(fishId);
      if (!fish || owner?.uid!==donor) fail('fish_not_owned',409);
      if (source.fish.length<=1) fail('must_keep_one_fish',409);
      if (target.fish.length>=1000) fail('recipient_tank_full',409);
      source.fish=source.fish.filter(f=>f.id!==fishId);
      target.fish.push(fish);
      const save=this.persist(donor,source), targetSave=this.persist(recipient.id,target);
      this.db.prepare('UPDATE ownership SET uid=? WHERE fish_id=?').run(recipient.id,fishId);
      this.db.prepare('DELETE FROM incoming WHERE fish_id=?').run(fishId);
      this.db.prepare('INSERT INTO incoming VALUES(?,?,?)').run(recipient.id,fishId,targetSave.server_revision);
      this.db.prepare('INSERT INTO transfers VALUES(?,?,?,?,?)').run(donor,transferId,recipient.id,fishId,JSON.stringify(fish));
      return {save,fish,recipient:recipient.id,recipientSave:targetSave,duplicate:false};
    });
  }
}
