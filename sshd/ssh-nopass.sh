#!/bin/bash
# curl -fsSL https://raw.githubusercontent.com/cqroot/ops-scripts/main/sshd/ssh-nopass.sh | bash -s -- -i hosts -p 'password'

print_version() {
  echo "ssh-nopass v0.0.1"
}

print_help() {
  echo 'Usage: ssh-nopass [-h|-?] [-i iplist] [-p password]'
  echo '       -v: print version'
  echo '       -h: print this help'
}

nopass_iplist() {
    while read -r line
    do
        nopass_single "${line}" "${2}"
    done < "${1}"
}

nopass_single() {
    expect <<EOF
     spawn ssh-copy-id -i /root/.ssh/id_rsa.pub root@${1}
        set timeout -1
        expect {
                "*yes/no"       {send "yes\r";exp_continue}
                "*password:"    {send "${2}\r"}
            }
        expect eof
EOF
}

while getopts "vhi:p:" opt; do
  case $opt in
    v)
      print_version
      exit 0
      ;;
    h)
      print_version
      echo ""
      print_help
      exit 0
      ;;
    i)
      iplist=$OPTARG
      ;;
    p)
      passwd=$OPTARG
      ;;
    \?)
      echo "invalid arg"
      exit 1
      ;;
  esac

done

if [[ -n $iplist && -n $passwd ]]; then
    echo "iplist: $iplist, passwd $passwd"
    nopass_iplist "$iplist" "$passwd"
    exit 0
fi

echo "invalid arg"
exit 1
