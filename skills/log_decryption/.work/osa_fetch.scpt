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
  set r to (do JavaScript "(function(){var body=JSON.stringify({0:'JutK/D8T1aFaL4VY5oYzU96Mey8aqRUcyGLsM+OAn4FVH5kXKMUMxSzzGTfY7Rwpx8LkF/DC1kq4fAoqRBWqOqGsgHeZ0B3sogpUadwUk5f9V18zI3wD4Z3j5l0GW2ZAeUqCIpqTQhjDKbQHnq7NLf4xDW1Pyzm1wRWaU/kn/qk=',1:'DxJyzQyj0vln+sHlVkBthqV565+EN7rS41w5VBui8jNNfBexbXeYHXyQq+dkgyTxO2fA9SQSSm0ESPQkRBtG+taCLPQ7jUcQEQ74L9Y1Or8GRIyjtPl3KfeB6+mEjQpoy29Y/yvyV3CB3SQeKFLUb7XTjSQ9oauvijemIkLc7jE='});var xhr=new XMLHttpRequest();xhr.open('POST','/log/decrypt/wear/decryptLogKeys',false);xhr.setRequestHeader('Content-Type','application/json');xhr.withCredentials=true;try{xhr.send(body);}catch(e){return 'ERR:'+String(e)+':'+xhr.status;}return xhr.responseText;})()" in theTab)
  return r
end tell
