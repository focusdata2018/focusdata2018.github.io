#!/bin/bash
m_date=$(date +%T)
echo -e "$m_date#start readweb process $$\n" >>processes.log
#https://sprosi.pro/questions/2617/kak-ya-mogu-poluchit-razmer-fayla-v-stsenarii-bash
function getfilesize(){
local file=""
if [[ "$1" ]]; then 
file="$1"
else
echo "File unknown in function getfilesize"
exit 1
fi
(
  du --apparent-size --block-size=1 "$file" 2>/dev/null ||
  gdu --apparent-size --block-size=1 "$file" 2>/dev/null ||
  find "$file" -printf "%s" 2>/dev/null ||
  gfind "$file" -printf "%s" 2>/dev/null ||
  stat --printf="%s" "$file" 2>/dev/null ||
  stat -f%z "$file" 2>/dev/null ||
  wc -c <"$file" 2>/dev/null
) | awk '{print $1}'
}

function get_http(){
DEST=""
if [[ "$1" ]]; then 
DEST="$1"
fi

PORT="80"
if [[ "$2" ]]; then 
PORT="$2"
fi

URLPATH="/"
if [[ "$3" ]]; then 
URLPATH="$3"
fi

(echo -e "GET $URLPATH HTTP/1.1\r\nHost: $DEST\r\nUser-Agent: Mozilla\r\nConnection: keep-alive\r\nAccept: */*\r\n\r\n"; sleep 1) | nc "$DEST" "$PORT" > orig.txt

local out=$((echo -e "GET $URLPATH HTTP/1.1\r\nHost: $DEST\r\nUser-Agent: Mozilla\r\nConnection: keep-alive\r\nAccept: */*\r\n\r\n"; sleep 1) | nc "$DEST" "$PORT" | base64)
local iserror=$(echo "$out" | grep "Bad Request")

if ! [[ "$iserror" ]]; then
  echo "$out"
else
  echo "BAD REQUEST to $DEST"
fi
}

function write_to_pipe()
{
local iscanwrite=true
while $iscanwrite
do
if read line <$pipe1; then
if [[ "$line" == 'EOP' ]]; then
iscanwrite=false
local m_date=$(date +%T)
local m_line="$1"

#delete \n in base data!!!!!
#https://www.linux.org.ru/forum/admin/5466918
m_line=$(echo "$m_line" | tr \\n \# | head --bytes -1)

#expr length not worked in big string
#http://citforum.ru/operating_systems/unixuser/gl3_10_5.shtml
send_size=$(echo "$m_line" | wc -c)
lines=$(echo "$m_line" | wc -l)

#https://www.opennet.ru/docs/RUS/bash_scripting_guide/x2565.html
if [ "$send_size" -gt "50" ]; then
echo -e "\n$m_date#to pipe1: \nsend size:$send_size, lines:$lines"
else
echo -e "\n$m_date#to pipe1: \n$m_line\nsend size:$send_size"
fi

echo "$m_line" >$pipe1
fi
fi
sleep 3
done

}

pipe1=/tmp/pipe1

if [[ ! -p $pipe1 ]]; then 
echo "Reader not running"
exit 1 
fi 

write_to_pipe "Hello from $$"

#echo "It will get info from $DEST:$PORT$URLPATH"
g_line=$(get_http "balsat-msk.ru")
write_to_pipe "$g_line"

write_to_pipe "quit"
#rest pipe1 befor end
read line <$pipe1
echo "Normal end of readweb"
exit 0
