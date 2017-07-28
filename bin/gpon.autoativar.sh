#!/bin/bash

. ../lib/include.sh


#IPS="10.11.11.3 10.11.11.4 10.2.1.90 10.3.1.90 10.11.11.2 10.11.11.5 10.0.58.90 10.0.58.80 10.110.25.90 10.110.25.91 10.101.42.90 172.18.20.90"
for IP in $(ls /etc/vlan_olt);do
	CADASTRARONU $IP
done

IP=$1
if [ "$IP" == "" ];then
	exit 0
fi
