#!/bin/zsh
# run_decrypt_loop.sh <LOG_DIR>
# Decrypt all encrypt_* logs under LOG_DIR into <dir>/decryption/ subdirectories.
# Loops prep→fetch AES keys via Safari same-origin POST→finish until encrypt_ count stable
# (handles bundled/nested encrypted logs inside decrypted archives).
#
# 前置: Safari 已登录 feedback.pt.xiaomi.com + 有一个 feedback.pt tab + AllowJavaScriptFromAppleEvents ON
set -o pipefail
LOG_DIR="${1:?usage: run_decrypt_loop.sh <LOG_DIR>}"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SKILL_DIR/.work"
mkdir -p "$OUT"
ASFILE="$OUT/osa_fetch.scpt"
log(){ printf '%s\n' "$*"; }
count_enc(){ find "$LOG_DIR" -type f -name 'encrypt_*' ! -name '_.tmp.*' 2>/dev/null | wc -l | tr -d ' '; }

for iter in 1 2 3 4 5 6; do
  before=$(count_enc)
  log "=== iteration $iter: $before encrypt files ==="
  rm -rf "$OUT"/* 2>/dev/null; mkdir -p "$OUT"
  node "$SKILL_DIR/prep.js" "$LOG_DIR" "$OUT" 2>&1
  BC=$(cat "$OUT/batchcount")
  for ((n=0;n<BC;n++)); do
    LIT=$(cat "$OUT/batch_$n.jsobj")
    cat > "$ASFILE" <<OASC
tell application "Safari"
  set theTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      try
        if (URL of t) contains "feedback.pt.xiaomi.com" then set theTab to t
      end try
    end repeat
    if theTab is not missing value then exit repeat
  end repeat
  if theTab is missing value then return "ERR: no feedback.pt.xiaomi.com tab (login + open any feedback.pt page)"
  set r to (do JavaScript "(function(){var body=JSON.stringify($LIT);var xhr=new XMLHttpRequest();xhr.open('POST','/log/decrypt/wear/decryptLogKeys',false);xhr.setRequestHeader('Content-Type','application/json');xhr.withCredentials=true;try{xhr.send(body);}catch(e){return 'ERR:'+String(e)+':'+xhr.status;}return xhr.responseText;})()" in theTab)
  return r
end tell
OASC
    resp=$(osascript "$ASFILE" 2>/dev/null)
    printf '%s' "$resp" > "$OUT/keys_batch_$n.json"
    log "batch $n: $(printf '%s' "$resp" | head -c 90)"
  done
  node "$SKILL_DIR/finish.js" "$LOG_DIR" "$OUT" 2>&1
  after=$(count_enc)
  log "iter $iter: before=$before after=$after"
  if (( after <= before )); then log "stable — no new encrypt files"; break; fi
done

log ""
log "=== FINAL ==="
log "encrypt (source, kept): $(count_enc)"
log "decrypted files: $(find "$LOG_DIR" -type f -path '*/decryption/*' ! -name '_.tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
log "total size: $(du -sh "$LOG_DIR" | cut -f1)"
