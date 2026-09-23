// Decrypt a wear encrypted log using the server-provided AES key.
// Usage: node decrypt.js <encFile> <base64Key> [outFile]
// Format: [128-byte key material][2-byte LE len + ciphertext group]...
// AES-256-CBC, IV = "A-16-Byte-String", Pkcs7, IV reset per group.
const fs = require('fs');
const crypto = require('crypto');

const inFile = process.argv[2];
const keyB64 = process.argv[3];
const outFile = process.argv[4];

if (!inFile || !keyB64) {
  process.stderr.write('usage: node decrypt.js <encFile> <base64Key> [outFile]\n');
  process.exit(2);
}

const key = Buffer.from(keyB64, 'base64');
const iv = Buffer.from('A-16-Byte-String', 'utf8');
const data = fs.readFileSync(inFile);

let pos = 128;
const parts = [];
let nGroup = 0;
while (pos < data.length) {
  if (pos + 2 > data.length) { process.stderr.write(`truncated len at ${pos}\n`); break; }
  const groupLen = data.readUInt16LE(pos); pos += 2;
  if (groupLen === 0 || pos + groupLen > data.length) { process.stderr.write(`bad group len ${groupLen} at ${pos}\n`); break; }
  const ct = data.slice(pos, pos + groupLen); pos += groupLen;
  try {
    const decipher = crypto.createDecipheriv('aes-' + (key.length * 8) + '-cbc', key, iv);
    let dec = decipher.update(ct);
    dec = Buffer.concat([dec, decipher.final()]);
    parts.push(dec);
    nGroup++;
  } catch (e) {
    process.stderr.write(`decrypt err group ${nGroup} (len ${groupLen}): ${e.message}\n`);
    break;
  }
}
const out = Buffer.concat(parts);
if (outFile) fs.writeFileSync(outFile, out);
else process.stdout.write(out);
process.stderr.write(`ok groups=${nGroup} in=${data.length} out=${out.length}\n`);
