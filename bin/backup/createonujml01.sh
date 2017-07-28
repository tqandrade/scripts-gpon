#!/bin/bash

IP="10.0.58.90"
COMMUNITY="VALENETZTE"
VLAN="2463"
MODEL=""
MODE="pppoe" #dhcp ou pppoe
CONTASIP="3131001010"
SENHASIP="ZZ38401000"


clear
if [ "$1" != "" ];then
IP=$1
else
echo -n "Informe o IP da OLT: "
read IP
fi

#'0x00 FC 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00' \
VLANHEX=`echo "ibase=10;obase=16;$VLAN" | bc | awk '{printf "%04s\n", $0}' | sed -e :a -e 's/^.\{1,47\}$/&0/;ta' | sed 's/../& /g'`

# TYPE: one of i, u, t, a, o, s, x, d, b
#      i: INTEGER, u: unsigned INTEGER, t: TIMETICKS, a: IPADDRESS
#      o: OBJID, s: STRING, x: HEX STRING, d: DECIMAL STRING, b: BITS
#      U: unsigned int64, I: signed int64, F: float, D: double
MIBS=+ALL
export MIBS

#VARIAVEIS GERAIS
COLOR='\033[1;33m'
NC='\033[0m' # No Color
TCONTID="1879048199"
INICIO="${COLOR}------------------------------------------------------------------"
FIM="------------------------------------------------------------------${NC}"

function display {
	printf "\n${INICIO}\n${1}\n${FIM}\n"
}

function pausa {
	echo -n "Pressione ENTER para continuar..."
	read READ
}

#REMOVE A ONU ATUAL
function ROLLBACK {
	display "OCORREU UM ERRO."
	pausa	
	snmpset -t120 -v2c -c $COMMUNITY $IP \
		.1.3.6.1.4.1.3902.1012.3.28.1.1.12.$ROW i 1 \
		.1.3.6.1.4.1.3902.1012.3.28.1.1.1.$ROW s ZTE-$MODEL \
		.1.3.6.1.4.1.3902.1012.3.28.1.1.5.$ROW x "0x$SERIAL" \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtEntryStatus.$ROW i 6

echo 1 	
}



display "IDENTIFICANDO ONUs SEM CONFIRURACAO"
#IDENTIFICA A ONU NAO CONFIGURADA
TMP=`snmpwalk -v2c -c $COMMUNITY $IP ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntInfoEntry | tail -1`
WALK="snmpwalk -v2c -c $COMMUNITY $IP  ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntSN"
CONT=`$WALK | wc -l`
if [ "$CONT" != 1 ];then
	display "SELECIONE A ONU DESEJADA"
	i=1
	$WALK | cut -d "=" -f 2 | while read line;do
		echo "$i: $line"
		i=`expr $i + 1`
	done
	echo -n "DIGITE O ITEM DESEJADO: "
	read ONUIDX
else
	ONUIDX=1
fi
snmpwalk -v2c -c $COMMUNITY $IP  ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntSN | head -$ONUIDX | tail -1
pausa

TMP=`snmpwalk -v2c -c $COMMUNITY $IP  ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntSN | head -$ONUIDX | tail -1`


if [ "`echo $TMP | grep -i 'no such'`" != "" ];then echo "NAO EXISTE ONU AGUARDANDO CONFIGURACAO"; exit; fi
ROW=`echo $TMP | cut -d "." -f 2,3 | cut -d " " -f 1`
PON=`echo $TMP | cut -d "." -f 2`

SERIAL=`echo $TMP | awk '{print $4$5$6$7$8$9$10$11}'`

USERNAME="$SERIAL"
PASSWORD="$SERIAL"
if [ "`expr substr $SERIAL 1 9`" == "5A544547C" ];then
	USERNAME=`expr substr $SERIAL 10 7`
	USERNAME="ZTEGC$USERNAME"
	PASSWORD=$USERNAME
	echo "SERIAL DETECTADO: $USERNAME"

fi


#CONVERTE O ROWID PARA BASE2
BIN=`echo "obase=2;$PON" | cut -d "." -f 1 | bc | awk '{printf "%032s\n", $0}'`
CHASSI=`expr substr $BIN 5 4`
CHASSI=`echo "obase=10;ibase=2;$SHELF" | bc`
CHASSI=`expr $SHELF + 1`

SLOT=`expr substr $BIN 9 8`
SLOT=`echo "obase=10;ibase=2;$SLOT" | bc`

PORTA=`expr substr $BIN 17 8`
PORTA=`echo "obase=10;ibase=2;$PORTA" | bc`

# BUSCANDO PELA OID zxGponOltPonRealLegalOnts PERDE-SE A SEQUENCIA
#ID=`snmpget -Ovq -v2c -c $COMMUNITY $IP zxGponOltPonRealLegalOnts.$PON `
#ID=`expr $ID + 1`
#ROW="$PON.$ID"
display "BUSCANDO VAGA NA OLT"
for i in `seq 255`;do
	if [ "`snmpget -v2c -c $COMMUNITY $IP zxGponONTSerialNum.${PON}.${i} | grep -i 'no such'`" != "" ];then
		ID=$i;
		ROW="$PON.$ID"
		echo $ID
		break;
	else
		echo "$i "
	fi
done



echo " $PON - $CHASSI/$SLOT/$PORTA:$ID"
echo "obase=2;ibase=10;$PON" | bc | awk  '{printf " %032s\n", $0}'



display "DETERMINANDO MODELO"
TMP2=`snmpwalk -v2c -c $COMMUNITY $IP ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntInfoEntry.10.$PON.1  -OvEQ | tail -1`
TMP2=`expr substr $TMP2 2 4`
if [[ $TMP2 == F6* ]];then
	echo "MODELO DETECTADO: $TMP2"
	MODEL=$TMP2
#else
#	echo "MODELO NAO LOCALIZADO! UTILIZANDO PADRAO $MODEL"
fi


##CUSTOM

if [[ "$MODEL" == "" ]];then
	while [[ "$MODEL" != "F601" && "$MODEL" != "F660" ]];do
		echo -n "Informe o Modelo (1 - F660, 2 - F601): ";
		read M;
		[ $M == 1 ] && MODEL="F660";
		[ $M == 2 ] && MODEL="F601";
	done
fi

echo -n "INFORME O CODIGO DE INSTALACAO: "
read USERNAME

if [[ "$MODEL" == "F660" ]];then
	MODEL="F660_1"
	echo -n "INFORME A SENHA DE CONEXAO: "
	read PASSWORD

	echo -n "VAI UTILIZAR TELEFONE NO ZTE [s/n]: ";
	read TEL
	if [ "$TEL" == "s" ];then
		echo -n "INFORME A CONTA SIP: "
		read CONTASIP
		echo -n "INFORME A SENHA SIP: "
		read SENHASIP
		
	fi
else
	MODE="dhcp"
fi

##/CUSTOM



display "CALCULANDO BRIDGEID"
#CALCULAR O BRIDGEID TYPE 4 INDEX
#|  4     |  4      |          8        |        8          |         8         |
#|Type: 4 |  Shelf  | Cardid(5b)Olt(3b) |       Onu         | Vport/SrvPortId   |
BRIDGEID="0100"
CHASSI=`expr $CHASSI - 1 `
S=`echo "obase=2;$CHASSI" | bc | awk '{printf "%04s\n", $0}'`
if [[ $SLOT -ge 2 && $SLOT -le 9 ]];then
	SLOT=`expr $SLOT - 2 `
elif [[ $SLOT -ge 12 && $SLOT -le 22 ]];then
	SLOT=`expr $SLOT - 4`
else
	SLOT=0
fi
C=`echo "obase=2;$SLOT" | bc | awk '{printf "%05s\n", $0}'`
PORTA=`expr $PORTA - 1 `
O=`echo "obase=2;$PORTA" | bc | awk '{printf "%03s\n", $0}'`
ID=`expr $ID - 1 `
U=`echo "obase=2;$ID" | bc | awk '{printf "%08s\n", $0}'`
V=`echo "obase=2;0" | bc | awk '{printf "%08s\n", $0}'`

BRIDGEID=`echo "obase=10;ibase=2;0100$S$C$O$U$V" | bc`
echo " 0100.$S.$C.$O.$U.$V"
echo -n " "
echo $BRIDGEID
pausa
display "CRIANDO TCONT T1-100M"
snmpset -v2c -c $COMMUNITY $IP \
	ZXGPON-SERVICE-MIB::zxGponBWProfileName.$TCONTID s 'T1-100M' \
	ZXGPON-SERVICE-MIB::zxGponBWProfileFixed.$TCONTID i 0 \
	ZXGPON-SERVICE-MIB::zxGponBWProfileAssured.$TCONTID i 0 \
	ZXGPON-SERVICE-MIB::zxGponBWProfileMaximum.$TCONTID i 100000 \
	ZXGPON-SERVICE-MIB::zxGponBWProfileType.$TCONTID i 4 \
	ZXGPON-SERVICE-MIB::zxGponBWProfileEntryStatus.$TCONTID i 4

if [ $? != 0 ];then echo "OCORREU UM ERRO"; exit; fi

display "CRIANDO ONU DENTRO DA INTERFACE DA OLT"
snmpset -v2c -c $COMMUNITY $IP \
	.1.3.6.1.4.1.3902.1012.3.28.1.1.12.$ROW i 1 \
	.1.3.6.1.4.1.3902.1012.3.28.1.1.1.$ROW s ZTE-$MODEL \
	.1.3.6.1.4.1.3902.1012.3.28.1.1.5.$ROW x "0x$SERIAL" \
	ZXGPON-SERVICE-MIB::zxGponOntDevMgmtEntryStatus.$ROW i 4 

if [ $? != 0 ];then echo "OCORREU UM ERRO"; exit; fi

#CONFIG TCONT
display "CONFIGURANDO TCONT PARA A INTERFACE DA ONU"
snmpset -v2c -c $COMMUNITY $IP \
.1.3.6.1.4.1.3902.1012.3.30.1.1.2.$ROW.1 s 'Tcont100M_1' \
.1.3.6.1.4.1.3902.1012.3.30.1.1.3.$ROW.1 i $TCONTID \
.1.3.6.1.4.1.3902.1012.3.30.1.1.8.$ROW.1 i 4 \

if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

display "CONFIGURANDO GEMPORT1 PARA A INTERFACE DA ONU"
#CRIAR GEMPORT
snmpset  -v2c -c $COMMUNITY $IP \
.1.3.6.1.4.1.3902.1012.3.30.2.1.2.$ROW.1 s 'Gem1' \
.1.3.6.1.4.1.3902.1012.3.30.2.1.3.$ROW.1 i 1 \
.1.3.6.1.4.1.3902.1012.3.30.2.1.4.$ROW.1 i 1 \
.1.3.6.1.4.1.3902.1012.3.30.2.1.10.$ROW.1 i 4 \

if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

if [ "$MODE" == "pppoe" ];then
	display "CONFIGURANDO PPPoE NA INTERFACE pon-onu-mng"
	#HABILITAR O PPPOE
	snmpset  -v2c -c $COMMUNITY $IP \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataNATEnable.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataMode.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataConnectTrigger.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataReleaseTimer.$ROW.1 i 1200 \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataUsername.$ROW.1 s $USERNAME \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataPassword.$ROW.1 s $PASSWORD \
		ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataEntryStatus.$ROW.1 i 4
	
	#CRIAR O SERVICO
	display "CRIANDO O DATASERVICE PARA A VLAN"
	snmpset  -v2c -c $COMMUNITY $IP \
		ZXGPON-ONTMGMT-MIB::zxGponServiceName.$ROW.1 s 'dataservice1' \
		ZXGPON-ONTMGMT-MIB::zxGponServiceType.$ROW.1 i 5 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceGemPort.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceMapType.$ROW.1 i 2 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceMapVlan.$ROW.1 x "0x$VLANHEX" \
		ZXGPON-ONTMGMT-MIB::zxGponServiceIfId.$ROW.1 i 131073 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceEntryStatus.$ROW.1 i 4 

		
	if [[ "$TEL" == "s" ]];then		
	  display "CONFIGURANDO CONTA SIP"
	  #DETERMINA O VOIP PROTOCOL
	  snmpset -v2c -c $COMMUNITY $IP \
	 	ZXGPON-ONTMGMT-MIB::zxGponVoIPConfigDataSignalProtocolUsed.$ROW.1 i 2
	
	  snmpset -d -v2c -c $COMMUNITY $IP \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataProxyServer.$ROW.1 s fs.voice.valenet.com.br \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataOutboundProxy.$ROW.1 s fs.voice.valenet.com.br \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataPrimaryDNS.$ROW.1 a 177.152.174.13 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataSecondaryDNS.$ROW.1 a 177.152.174.14 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataUDPTCPPort.$ROW.1 i 5060 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataHostId.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataRegExpTime.$ROW.1 i 3600 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataReRegStartTime.$ROW.1 i 360 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataRegServer.$ROW.1 s fs.voice.valenet.com.br \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataValidatScheme.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataEntryStatus.$ROW.1 i 4
	
	  snmpset -d -v2c -c $COMMUNITY $IP \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataAgentId.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataUserPartAOR.$ROW.1 s $CONTASIP \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataDisplayName.$ROW.1 s $CONTASIP \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataUserName.$ROW.1 s $CONTASIP \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataPassword.$ROW.1 s $SENHASIP \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailServerURI.$ROW.1 s '' \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailValidateScheme.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailUserName.$ROW.1 s '' \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailPassword.$ROW.1 s '' \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailRealm.$ROW.1 s '' \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailSubsciptExpTime.$ROW.1 i 3600 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataNetworkDialPlanPtr.$ROW.1 i 0 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataServiceProfilePtr.$ROW.1 i 0 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataFeatureCodePtr.$ROW.1 i 0 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataReleaseTimer.$ROW.1 i 10 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataROHTimer.$ROW.1 i 15 \
		ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataEntryStatus.$ROW.1 i 4 
	fi
	
else

	#HABILITAR DHCP
	display "CONFIGURANDO DHCP NA INTERFACE pon-onu-mng"
	snmpset  -v2c -c $COMMUNITY $IP \
        	ZXGPON-ONTMGMT-MIB::zxGponIPHostConfigDataIPOptions.$ROW.1 i 3 \
	        ZXGPON-ONTMGMT-MIB::zxGponIPHostConfigDataOntIdentifier.$ROW.1 s $USERNAME 
	
	#MODO TRANSPARENTE
	snmpset  -v2c -c $COMMUNITY $IP \
		ZXGPON-ONTMGMT-MIB::zxGponVlanPortMode.$ROW.1.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponVlanPortPvid.$ROW.1.1 i $VLAN 
		
		
	#CRIAR O SERVICO
	display "CRIANDO O DATASERVICE PARA A VLAN"
	snmpset  -v2c -c $COMMUNITY $IP \
		ZXGPON-ONTMGMT-MIB::zxGponServiceName.$ROW.1 s 'dataservice1' \
		ZXGPON-ONTMGMT-MIB::zxGponServiceType.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceGemPort.$ROW.1 i 1 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceMapType.$ROW.1 i 2 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceMapVlan.$ROW.1 x "0x$VLANHEX" \
		ZXGPON-ONTMGMT-MIB::zxGponServiceIfId.$ROW.1 i 131073 \
		ZXGPON-ONTMGMT-MIB::zxGponServiceEntryStatus.$ROW.1 i 4 


fi        

if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

	
if [ $? != 0 ];then echo "OCORREU UM ERRO AO CRIAR O DATASERVICE 1";ROLLBACK; exit; fi

#CRIAR A SERVICE PORT

#BRIDGEID=Type 4 Index
#BRIDGEID="1074266112.1"
display "CRIANDO A SERVICE PORT"
snmpset  -v2c -c $COMMUNITY $IP \
        ZTE-AN-SERVICEPORT::zxAnServicePortDesc.$BRIDGEID.1 s "$USERNAME" \
        ZTE-AN-SERVICEPORT::zxAnServicePortServiceMode.$BRIDGEID.1 i 4 \
        ZTE-AN-SERVICEPORT::zxAnUserInVid.$BRIDGEID.1 i $VLAN \
        ZTE-AN-SERVICEPORT::zxAnUserInPriority.$BRIDGEID.1 i 0 \
        ZTE-AN-SERVICEPORT::zxAnUserEthType.$BRIDGEID.1 i 1 \
        ZTE-AN-SERVICEPORT::zxAnUserEthFilter.$BRIDGEID.1 i 2 \
        ZTE-AN-SERVICEPORT::zxAnUserOutCVid.$BRIDGEID.1 i $VLAN \
        ZTE-AN-SERVICEPORT::zxAnVlanTransMode.$BRIDGEID.1 i 1




display "ONU CADASTRADA COM SUCESSO"
pausa "PRESSIONE ENTER PARA SAIR"

exit 0
