jq '

def rpad(string;len;fill):
  if len == 0 then string else (string + (fill * len))[0:len] end;

to_entries | map("\(rpad(.value;4;" "))'\u2008'\(.key)") | .[]

' abbreviations.json -r > abbreviations.txt
