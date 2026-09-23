// finish.js — merge keys from keys_batch_*.json, decrypt every file, extract archives
// into <encrypt_dir>/decryption/.
// usage: node finish.js <LOG_DIR> <OUT>
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');
const DEST = process.argv[2];
const OUT = process.argv[3];
if (!DEST || !OUT) { console.error('usage: node finish.js <LOG_DIR> <OUT>'); process.exit(2); }
const IV = Buffer.from('A-16-Byte-String', 'utf8');

const filemap = JSON.parse(fs.readFileSync(path.join(OUT, 'filemap.json'), 'utf8'));
const keys = {};
for (const n of fs.readdirSync(OUT).filter(x => x.startsWith('keys_batch_'))) {
  const txt = fs.readFileSync(path.join(OUT, n), 'utf8').trim();
  if (!txt) { process.stderr.write(n + ': empty\n'); continue; }
  if (txt.startsWith('ERR')) { process.stderr.write(n + ': ' + txt.slice(0, 160) + '\n'); continue; }
  try { Object.assign(keys, JSON.parse(txt)); }
  catch (e) { process.stderr.write(n + ' parse: ' + e + '\n'); }
}

let ok = 0, fail = 0, ext = 0;
for (const f of filemap) {
  const kb = keys[f.uid];
  if (!kb) { process.stderr.write('[fail] ' + f.name + ' (no key)\n'); fail++; continue; }
  const key = Buffer.from(kb, 'base64');
  let data;
  try { data = fs.readFileSync(f.path); } catch (e) { process.stderr.write('[fail] ' + f.name + ' read\n'); fail++; continue; }
  let out;
  try {
    let pos = 128; const parts = [];
    while (pos < data.length) {
      if (pos + 2 > data.length) break;
      const gl = data.readUInt16LE(pos); pos += 2;
      if (gl === 0 || pos + gl > data.length) break;
      const ct = data.slice(pos, pos + gl); pos += gl;
      const d = crypto.createDecipheriv('aes-' + (key.length * 8) + '-cbc', key, IV);
      parts.push(d.update(ct), d.final());
    }
    out = Buffer.concat(parts); ok++;
  } catch (e) { process.stderr.write('[fail] ' + f.name + ' decrypt: ' + e.message + '\n'); fail++; continue; }
  const outName = f.name.replace(/^encrypt_/, '');
  // 解密产物统一落到 <encrypt_dir>/decryption/（per 用户要求）
  const decDir = path.join(f.dir, 'decryption');
  fs.mkdirSync(decDir, { recursive: true });
  if (out.length >= 4 && out[0] === 0x50 && out[1] === 0x4b && out[2] === 0x03 && out[3] === 0x04) {
    // zip
    const tmp = path.join(decDir, '_.tmp.' + outName + '.zip');
    fs.writeFileSync(tmp, out);
    try { execSync('unzip -o -q "' + tmp + '" -d "' + decDir + '"'); ext++; }
    catch (e) { process.stderr.write('[warn] unzip ' + outName + ': ' + e.message + '\n'); }
    fs.rmSync(tmp, { force: true });
  } else if (out.length >= 2 && out[0] === 0x1f && out[1] === 0x8b) {
    // gzip / tar.gz
    const tmp = path.join(decDir, '_.tmp.' + outName);
    fs.writeFileSync(tmp, out);
    try { execSync('tar -xf "' + tmp + '" -C "' + decDir + '"'); ext++; }
    catch (e) { process.stderr.write('[warn] untar ' + outName + ': ' + e.message + '\n'); }
    fs.rmSync(tmp, { force: true });
  } else {
    // plaintext log
    fs.writeFileSync(path.join(decDir, outName), out);
  }
}
process.stderr.write('done: ' + ok + ' decrypted, ' + ext + ' archives extracted, ' + fail + ' failed (of ' + filemap.length + ')\n');
