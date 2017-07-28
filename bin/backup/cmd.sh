COMMUNITY=VALENETZTE
IP=10.11.11.3
ROW=269420288
VLANHEX_TR="07 D0 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
MIBS=+ALL
export MIBS

snmpset  -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponServiceName.$ROW.2 s 'dataservice2' \
			ZXGPON-ONTMGMT-MIB::zxGponServiceType.$ROW.2 i 5 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceGemPort.$ROW.2 i 2 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceMapType.$ROW.2 i 2 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceMapVlan.$ROW.2 x "0x$VLANHEX_TR" \
			ZXGPON-ONTMGMT-MIB::zxGponServiceIfId.$ROW.2 i 0 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceEntryStatus.$ROW.2 i 4 