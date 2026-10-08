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
  set r to (do JavaScript "(function(){var body=JSON.stringify({0:'lkV3KdAr7EMMxXm2/KONAK1oHMoAVX8nmk3znUqL+hidVEXDhCHP0HcFCY9v4bSv/q8DK0MoOg56yNeu4EFml82UqWp2BorvMoIV8tqWK8huuoMydCb5uiQCciH13m3v5QnYeh5azk1o3JeAZcxNz5nD3MrWvDipHSZp3gXyhLM=',1:'SRab8tueL+ALfCuindg4AAJgTH9gNhDbhj1siei1UyK1nC2MH+rdUmoQOp/VFCZ3+OIFuVXyVSvPtmEr3pH1orket0qGvVNZ/MM2+W3E4twqvna4jUc2XySsPpvZM/1NPNuWnyZCza0Vh4hwDbSGndgjibQJyO2DvSajrs7xFbE='});var xhr=new XMLHttpRequest();xhr.open('POST','/log/decrypt/wear/decryptLogKeys',false);xhr.setRequestHeader('Content-Type','application/json');xhr.withCredentials=true;try{xhr.send(body);}catch(e){return 'ERR:'+String(e)+':'+xhr.status;}return xhr.responseText;})()" in theTab)
  return r
end tell
