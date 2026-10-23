// Private file storage with short-lived links.
//  - Supabase Storage (private bucket) when SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set
//  - otherwise backend/uploads on this computer (development and tests), served by /api/files
//    through HMAC-signed links that expire, so both behave the same way for the app.

const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const env = require('../config/env');

const LINK_TTL_SECONDS = 60 * 60;   // links for images in the app last one hour
const LOCAL_ROOT = path.join(__dirname, '..', '..', 'uploads');

const sign = (filePath, expires) =>
  crypto.createHmac('sha256', env.jwtSecret).update(`${filePath}:${expires}`).digest('base64url');

const supabase = {
  async upload(filePath, buffer, contentType) {
    const res = await fetch(`${env.storage.supabaseUrl}/storage/v1/object/${env.storage.bucket}/${filePath}`, {
      method: 'POST',
      headers: this.headers({ 'Content-Type': contentType, 'x-upsert': 'true' }),
      body: buffer,
    });
    if (!res.ok) throw new Error(`Storage upload failed (${res.status}): ${await res.text()}`);
  },
  async remove(filePath) {
    await fetch(`${env.storage.supabaseUrl}/storage/v1/object/${env.storage.bucket}`, {
      method: 'DELETE',
      headers: this.headers({ 'Content-Type': 'application/json' }),
      body: JSON.stringify({ prefixes: [filePath] }),
    });
  },
  async signedUrl(filePath) {
    const res = await fetch(`${env.storage.supabaseUrl}/storage/v1/object/sign/${env.storage.bucket}/${filePath}`, {
      method: 'POST',
      headers: this.headers({ 'Content-Type': 'application/json' }),
      body: JSON.stringify({ expiresIn: LINK_TTL_SECONDS }),
    });
    if (!res.ok) return null;
    const { signedURL } = await res.json();
    return `${env.storage.supabaseUrl}/storage/v1${signedURL}`;
  },
  headers(extra) {
    return { Authorization: `Bearer ${env.storage.serviceRoleKey}`, apikey: env.storage.serviceRoleKey, ...extra };
  },
};

const local = {
  async upload(filePath, buffer) {
    const target = local.resolve(filePath);
    await fs.mkdir(path.dirname(target), { recursive: true });
    await fs.writeFile(target, buffer);
  },
  async remove(filePath) {
    await fs.rm(local.resolve(filePath), { force: true });
  },
  // baseUrl is the address the app used to reach this server (e.g. http://10.0.2.2:4000)
  async signedUrl(filePath, baseUrl) {
    const expires = Math.floor(Date.now() / 1000) + LINK_TTL_SECONDS;
    return `${baseUrl}/api/files/${filePath}?expires=${expires}&sig=${sign(filePath, expires)}`;
  },
  resolve(filePath) {
    const target = path.resolve(LOCAL_ROOT, filePath);
    if (!target.startsWith(LOCAL_ROOT + path.sep)) throw new Error('Invalid file path');
    return target;
  },
  // used by the /api/files route
  verify(filePath, expires, sig) {
    if (!expires || !sig || Number(expires) < Date.now() / 1000) return false;
    const expected = Buffer.from(sign(filePath, Number(expires)));
    const given = Buffer.from(String(sig));
    return expected.length === given.length && crypto.timingSafeEqual(expected, given);
  },
};

const driver = () => (env.storage.useSupabase && !env.isTest ? supabase : local);

module.exports = {
  upload: (filePath, buffer, contentType) => driver().upload(filePath, buffer, contentType),
  remove: filePath => (filePath ? driver().remove(filePath) : undefined),
  signedUrl: (filePath, baseUrl) => (filePath ? driver().signedUrl(filePath, baseUrl) : null),
  local,
};
