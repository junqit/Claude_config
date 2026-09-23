// prep.js — scan <LOG_DIR>/encrypt_* files recursively, write filemap.json + batch object literals.
// usage: node prep.js <LOG_DIR> <OUT>
const fs = require('fs');
const path = require('path');
const DEST = process.argv[2];
const OUT = process.argv[3];
if (!DEST || !OUT) { console.error('usage: node prep.js <LOG_DIR> <OUT>'); process.exit(2); }
fs.mkdirSync(OUT, { recursive: true });

// recursive walk — archives may extract into more encrypt_ files (bundled logs)
function walk(dir, acc) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '_.tmp.') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (e.isFile() && e.name.startsWith('encrypt_')) acc.push(p);
  }
  return acc;
}
const allPaths = walk(DEST, []).sort();
const files = [];
let uid = 0;
for (const fp of allPaths) {
  const fd = fs.openSync(fp, 'r');
  const buf = Buffer.alloc(128);
  fs.readSync(fd, buf, 0, 128, 0);
  fs.closeSync(fd);
  files.push({ uid: String(uid), path: fp, name: path.basename(fp), dir: path.dirname(fp), b64: buf.toString('base64') });
  uid++;
}
fs.writeFileSync(path.join(OUT, 'filemap.json'), JSON.stringify(files.map(f => ({ uid: f.uid, path: f.path, name: f.name, dir: f.dir }))));
const BSIZE = 20;
let bn = 0;
for (let i = 0; i < files.length; i += BSIZE) {
  const chunk = files.slice(i, i + BSIZE);
  // JS object literal {uid:'b64',...} — base64 has no quote/backslash, safe single-quoted
  const lit = '{' + chunk.map(f => f.uid + ":'" + f.b64 + "'").join(',') + '}';
  fs.writeFileSync(path.join(OUT, 'batch_' + bn + '.jsobj'), lit);
  bn++;
}
fs.writeFileSync(path.join(OUT, 'batchcount'), String(bn));
process.stderr.write('files=' + files.length + ' batches=' + bn + '\n');
