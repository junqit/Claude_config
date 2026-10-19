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
  set r to (do JavaScript "(function(){var body=JSON.stringify({0:'QmIANKeehnLlryymbclqgYzdtA7+gvTc57INZ1gzAPHzBC3Pcd3b/bcs4loiaf2O5CVp/uGD1SPxcmiQp31Vsz3ehbRSE9SA0ppiGXLLLi1DopSSJQWksZGcbn9gjXkQGtav1yL9HjQUywFgihWfaSYCHu4vClJptEoFttby+ak=',1:'dRjg7rBG8xCI8NEc7KNtjoI4CYH0WTomsDD/KUyVD2mez+OrKPyYLLcrU0XsgaDjfQ5uVQLQd4am8+W2GS0Mu+p/Vi+DDp94IB+bQcVkKiQofdKWQKasYolCvJ/bZkRz9RfdRah0mK5cuemetfTaqvfPQpgtaJ8K4iarq59A2/s='});var xhr=new XMLHttpRequest();xhr.open('POST','/log/decrypt/wear/decryptLogKeys',false);xhr.setRequestHeader('Content-Type','application/json');xhr.withCredentials=true;try{xhr.send(body);}catch(e){return 'ERR:'+String(e)+':'+xhr.status;}return xhr.responseText;})()" in theTab)
  return r
end tell
