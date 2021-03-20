#!/usr/bin/bash

#stty -echoctl

trap '[[ `ls $tmp/res/` ]] && cat  $tmp/res/* | sort > $output; rm -rf $tmp; if ps -Af | grep "com\.termux" >/dev/null; then killall -9 tor; fi' EXIT

tmp=$(mktemp -d --tmpdir=.)
mkdir $tmp/req $tmp/res
proxy="127.0.0.1:9050"
exact=1
exactdom=1
wild="%"
cmd="echo %"
output=$(date +%d-%m-%d_%H-%M.txt)
jobs=5
status=false

usage(){
  echo -e """pwndb.sh

usage:
-u|--user [USER]          user to check
-U|--user-list [FILE]     file containing users (1 per line)
-e|--exact                check exact user
-d|--domain [DOMAIN]      domain
-D|--domain-list [FILE]   file containing domains (1 per line)
-b|--brute-force [NUMBER] brute force   1 will be A to Z ,
                                        2 will be AA to ZZ
-j|--jobs [number]        number of background jobs (default 5)
-p|--password [PASSWORD]  search email from password
-P|--pasword-list [FILE]  file containing password (1 per line)
-o|--output [file]        output file
-x|--proxy [IP:PORT]      proxy and port of TOR
-s|--server-status        check if pwndb server is up and exit

whildecard character is "%"

exemples:
pwndb -u crime -e -d gmail.com -o result.txt
pwndb -u crime
pwndb -U user.lst -D domain.lst -x 127.0.0.1:9999
pwndb -b 2 -d gmail.com -o result.txt
pwndb -b 4 -j 10 -d "%.gouv.fr" 
pwnd -p fuckthepopo -j 10 -o res.lst -x 192.168.75.225:9050 
pwndb -S -u "test" -d "gmail.com"
"""
}


if [[ ${#@} > 0 ]]; then
  while [ "$1" != "" ]; do
    case $1 in
      -u | --user )
        shift
        user="$1"
        cmd="echo \"$1\""
        ;;
      -U | -user-list)
        shift
        cmd="cat $1"
        ;;
      -e | --exact-user)
        exact=0
        wild=""
        ;;
      -d | --domain )
        shift
        domain=true
        domainname="$1"
        cmddom="echo $1"
        ;;
      -E | --exact-domain)
        exact=true
        exactdom=0
        ;;
      -D|--domain-list)
        shift
        domain=true
        cmddom="cat $1"
        ;;
      -b | --brute-force)
        shift
        list=true
        iterate_nbr=$(eval printf '\{a..z\}%.0s' {1..$1})
        cmd="printf '%s\\n' $iterate_nbr"
        ;;
      -p|--password)
        shift
        domain=false
        passwd=true
        password="$1"
        cmd="echo $1"
        ;;
      -P|--password-list)
        shift
        passwd=true
        cmd="cat $1"
        ;;
      -j|--jobs)
        shift
        [[ "$1" > 10 ]] && echo "cant use more than 10 jobs" && sleep 1 && usage && exit 1
        jobs="$1"
        ;;
      -o|--output)
        shift
        output="$1"
        ;;
      -x|--proxy)
        shift
        proxy="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -s|--server-status)
        status=true
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    shift
  done
else
  usage
  exit 1
fi

# check for termux

if ps -Af | grep "com\.termux" > /dev/null ; then
  if ! ps -A | grep tor >/dev/null ; then
    echo "starting tor ..."
    tor >/dev/null &
    sleep 8
  fi
fi

pwait(){
  while [ $(jobs -p | wc -l) -ge $1 ]; do
    sleep 1
  done
}



check_if_up (){
while true; do
  for X in '-' '/' '|' '\'; do
    printf "\e[33m\rChecking if pwndb is up $X"
  sleep 0.1
  done
done
}
check_if_up &
check_pid=$!

status_code=$(curl  --max-time 10 -sk -w "%{http_code}" --socks5-hostname $proxy pwndb2am4tzkvold.onion)
(kill $check_pid 2>&1) >/dev/null
echo -ne "\r\033[K"

if [[ $status_code == "000" ]]; then
  echo -e "\e[31mPwndb server is down ..."
  if [[ $status != true ]]; then
    exit 1
  fi
else
  if [[ $status == true ]]; then
    echo -e "\e[32mPwndb is up"
    exit 0
  fi
fi


[[ $domain == true ]] && [[ $passwd == true ]] && echo "Cant search password and domain at the same time" && exit 1
[[ -z $cmd ]] && cmd="echo %" && wild=''
[[ -z $cmddom ]] && cmddom="echo %" && wild=''

passwd(){
    echo -ne "\r\e[0K\e[0m[`date -u -d @${SECONDS} +"%T"`]──→[$1]"
  until [[ $(curl  -sk -o "$tmp/req/$1.txt" -w "%{http_code}" --socks5-hostname $proxy -d "password=$1&submitform=pw"  pwndb2am4tzkvold.onion) == 200 ]] ; do 
    echo -ne "\r\e[0KProblem occurs... restart $line"
    sleep 3 
  done
  while IFS= read -r line; do
    if grep -E "^(" <<<"$line" 2>/dev/null; then user="" && domain="" && pass="" ; fi
    if grep '\[luser\] =' <<<"$line" >/dev/null; then user="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[domain\] =' <<<"$line" >/dev/null ; then domain="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[password\] =' <<<"$line" >/dev/null ; then pass="$(cut -d ' ' -f7 <<<"$line")"; fi
    [[ $line == ")" ]] && [[ -n $user ]] && echo -ne "\r\e[31m[\e[37m$1\e[31m]──→[\e[33m$user\e[0m@\e[37m$domain\e[0m:\e[36m$pass\e[31m]\n" && echo "$user@$domain:$pass" >> "$tmp/res/$1.txt"
  done < <(eval pup pre < $tmp/req/$1.txt | sed '1,11d;$d')
}


req_n_parse(){
  [[ $1 == "%" ]] && usr="all" || usr=$1
  echo -ne "\r\e[0K\e[0m[`date -u -d @${SECONDS} +"%T"`]──→[$usr]"
  until [[ $(curl  -sk -o "$tmp/req/$1.txt" -w "%{http_code}" --socks5-hostname $proxy -d "luser=$1$2&domain=$3&luseropr=$4&domainopr=1&submitform=em"  pwndb2am4tzkvold.onion) == 200 ]] ; do 
    echo -ne "\r\e[0KProblem occurs... restart $line"
    sleep 3 
  done
  while IFS= read -r line; do
    if grep -E "^(" <<<"$line" 2>/dev/null; then user="" && domain="" && pass="" ; fi
    if grep '\[luser\] =' <<<"$line" >/dev/null; then user="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[domain\] =' <<<"$line" >/dev/null ; then domain="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[password\] =' <<<"$line" >/dev/null ; then pass="$(cut -d ' ' -f7 <<<"$line")"; fi
    [[ $line == ")" ]] && [[ -n $user ]] && echo -ne "\r\e[31m[\e[37m$usr\e[31m]──→[\e[33m$user\e[0m@\e[37m$domain\e[0m:\e[36m$pass\e[31m]\n" && echo "$user@$domain:$pass" >> "$tmp/res/$usr.txt"
  done < <(eval pup pre < $tmp/req/$1.txt | sed '1,11d;$d')
  rm $tmp/req/$1.txt
}

if [[ $passwd == true ]]; then
  while IFS= read -r passd; do
    passwd $passd &
    pwait $jobs
  done < <(eval $cmd)
  wait
  exit
fi

while IFS= read -r dom; do
  while IFS= read -r line; do
    req_n_parse "$line" "$wild" "$dom" $exact & 
    pwait $jobs
  done < <(eval $cmd)
done < <(eval $cmddom)
wait

if ! ls $tmp/res/*.txt 1> /dev/null 2>&1; then
  echo -e "\r\e[0K\e[38;5;15;48;5;196mNo results found ...\e[0m"
fi
echo -e "\e[33mDuration: `date -u -d @${SECONDS} +"%T"`"
