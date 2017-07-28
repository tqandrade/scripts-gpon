#!/bin/bash
IP=$1
SN=$2
if [ "$IP" == "" ];then
	echo "usage: $0 IP SN"
	exit 0;
fi


function TRANSLATEPORTA {
	PON=`echo $1 | cut -d "." -f 1`
	IDX=`echo $1 | cut -d "." -f 2`
	if [ "$IDX" != "" ];then
		IDX=":$IDX"
	fi
	BIN=`echo "obase=2;$PON" | cut -d "." -f 1 | bc | awk '{printf "%032s\n", $0}'`
	CHASSI=`expr substr $BIN 5 4`
	CHASSI=`echo "obase=10;ibase=2;$SHELF" | bc`
	CHASSI=`expr $SHELF + 1`

	SLOT=`expr substr $BIN 9 8`
	SLOT=`echo "obase=10;ibase=2;$SLOT" | bc`

	PORTA=`expr substr $BIN 17 8`
	PORTA=`echo "obase=10;ibase=2;$PORTA" | bc`
	
	echo -n $CHASSI/$SLOT/$PORTA$IDX
}





#snmpwalk -v2c -c VALENETZTE $IP .1.3.6.1.4.1.3902.1012.3.28.1.1.5 | awk '{print $1" ZTEG"$8$9$10$11}' | cut -d '.' -f 2,3 | grep "$SN" | while read LINHA;do
#$STRFILE=""
#echo "************ $LINHA ***************"
#PON=`echo $LINHA | cut -d "." -f 1`
#TRANSLATEPORTA "$PON "
#echo -n " "
#echo -n $LINHA | cut -d "." -f 2 | cut -d " " -f 1
#ROWID=`echo $LINHA | cut -d " " -f 1`
#echo -n "TYPE: "
#snmpwalk -v2c -c VALENETZTE $IP .1.3.6.1.4.1.3902.1012.3.28.1.1.1.$ROWID
#echo -n "STATUS: "
#snmpwalk -v2c -c VALENETZTE $IP 1.3.6.1.4.1.3902.1012.3.28.2.1.4.$ROWID
#
#echo -n "USERNAME: "
#snmpwalk -v2c -c VALENETZTE $IP ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataUsername.$ROWID.1

#done


#BUSCA A LISTA DE ONUs em LOS
snmpwalk -v2c -c VALENETZTE $IP .1.3.6.1.4.1.3902.1012.3.28.2.1.4 | \
	grep -i los | \
	cut -d "." -f 2,3 | \
	cut -d " " -f 1 | \
	while read line;do  
#		echo $line; 
		#BUSCA O SN DA ONU
		SN=`snmpwalk -v2c -c VALENETZTE $IP .1.3.6.1.4.1.3902.1012.3.28.1.1.5.$line | awk  '{print " ZTEG"$8$9$10$11}'`; 
		USERNAME=`snmpwalk -v2c -c VALENETZTE $IP ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataUsername.$line.1 | cut -d " " -f 4`
		echo -n "$SN $USERNAME "
		
		TRANSLATEPORTA $line
		echo ""
	done