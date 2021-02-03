#!/bin/bash

ips="\
host1,pass
host2,pass
"

noPass() {
    for i in $ips;do
        ip=$(echo "$i" |cut -d',' -f1)
        pass=$(echo "$i" |cut -d',' -f2)
        noPassExpect "${ip}" "${pass}"
    done
}

noPassExpect() {
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

if [ -z "${1}" ] && [ -z "${2}" ];then
    noPass
else
    noPassExpect "${1}" "${2}"
fi
