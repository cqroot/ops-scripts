#!/bin/bash

sed -i "s/#UseDNS yes/UseDNS no/"  /etc/ssh/sshd_config
sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
service sshd restart
