#!/bin/bash

MIBS="+ALL"
export MIBS


COMMUNITY="VALENETZTE"
MODEL=""
MODE="pppoe" #dhcp ou pppoe
TCONTID="1879048199"


function display {
	#printf "\n${INICIO}\n${1}\n${FIM}\n"
	echo "${1}"
}
function pausa {
	echo -n "Pressione ENTER para continuar..."
	read READ
}


function ROLLBACK {
	display "OCORREU UM ERRO."
#	pausa	
	snmpset -t120 -v2c -c $COMMUNITY $IP \
		ZXGPON-SERVICE-MIB::zxGponOntRegMode.$ROW i 1 \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtTypeName.$ROW s ZTE-$MODEL \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtProvisionSn.$ROW x "0x$SERIAL" \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtEntryStatus.$ROW i 6

echo 1 	
}


function UNCFGONU {
	PON="";ROW="";SERIAL="";SERIAL_HUMAN=""
	
	
	display "IDENTIFICANDO ONUs SEM CONFIRURACAO PARA $IP"
	
	TMP=`snmpwalk -v2c -c $COMMUNITY $IP ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntInfoEntry | tail -1`
	WALK="snmpwalk -v2c -c $COMMUNITY $IP  ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntSN"
	CONT=`$WALK | grep -v Such | wc -l`
	
	if [ "$CONT" == "0" ];then
		display "NENHUMA ONU AGUARDANDO CONFIGURACAO"
#		exit 0;
#		break
		export PON
		export ROW
		export SERIAL
		export SERIAL_HUMAN
		return 0
	fi
	display "ONUs LOCALIZADAS:"
	i=1
	$WALK | cut -d "=" -f 2 | while read line;do
		echo "$i: $line"
		i=`expr $i + 1`
	done
	ONUIDX=1
	
	TMP=`snmpwalk -v2c -c $COMMUNITY $IP  ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntSN | head -$ONUIDX | tail -1`


	if [ "`echo $TMP | grep -i 'no such'`" != "" ];then echo "NAO EXISTE ONU AGUARDANDO CONFIGURACAO"; exit; fi
	ROW=`echo $TMP | cut -d "." -f 2,3 | cut -d " " -f 1`
	PON=`echo $TMP | cut -d "." -f 2`

	SERIAL=`echo $TMP | awk '{print $4$5$6$7$8$9$10$11}'`
	SERIAL_HUMAN=$SERIAL
	if [ "`expr substr $SERIAL 1 8`" == "5A544547" ];then
		SERIAL_HUMAN=`expr substr $SERIAL 9 8`
		SERIAL_HUMAN="ZTEG$SERIAL_HUMAN"
	fi
	
	if [ "`expr substr $SERIAL 1 8`" == "434D535A3" ];then
		SERIAL_HUMAN=`expr substr $SERIAL 9 8`
		SERIAL_HUMAN="CMSZ$SERIAL_HUMAN"
	fi
	export PON
	export ROW
	export SERIAL
	export SERIAL_HUMAN
	
}


function PORTACHASSISLOT {
	PON=`echo $1 | cut -d "." -f 1`
	ID=`echo $1 | cut -d "." -f 2`
	BIN=`echo "obase=2;$PON" | cut -d "." -f 1 | bc | awk '{printf "%032s\n", $0}' | sed 's/ /0/g;'`
	CHASSI=`expr substr $BIN 5 4`
	CHASSI=`echo "obase=10;ibase=2;$SHELF" | bc`
	CHASSI=`expr $SHELF + 1`

	SLOT=`expr substr $BIN 9 8`
	SLOT=`echo "obase=10;ibase=2;$SLOT" | bc`

	PORTA=`expr substr $BIN 17 8`
	PORTA=`echo "obase=10;ibase=2;$PORTA" | bc`
	
	
	
	
	export CHASSI
	export SLOT
	export PORTA
	export ID
	
	

}

function CRIARONU {
	
	for i in `seq 255`;do
		if [ "`snmpget -v2c -c $COMMUNITY $IP zxGponONTSerialNum.${PON}.${i} | grep -i 'no such'`" != "" ];then
			ID=$i;
			ROW="$PON.$ID"
			export ROW
			export ID
			#echo $i
			break;
		fi
	done
	
	
	
}

function MODELO {
	TMP2=`snmpwalk -v2c -c $COMMUNITY $IP ZXGPON-SERVICE-MIB::zxGponUnCfgSnOntInfoEntry.10.$PON.1  -OvEQ | tail -1`
	TMP2=`expr substr $TMP2 2 4`
	if [[ $TMP2 == F6* ]];then
		echo $TMP2
	#else
	#	echo "MODELO NAO LOCALIZADO! UTILIZANDO PADRAO $MODEL"
	fi

}


function CADASTRARONU {
	IP=$1
	
	
	VLAN=$(cat /etc/vlan_olt/$IP)
	VLAN_TR=2204
	VLANHEX=`echo "ibase=10;obase=16;$VLAN" | bc | awk '{printf "%04s\n", $0}' | sed 's/ /0/g;' | sed -e :a -e 's/^.\{1,47\}$/&0/;ta' | sed 's/../& /g'`
	VLANHEX_TR=`echo "ibase=10;obase=16;$VLAN_TR" | bc | awk '{printf "%04s\n", $0}' | sed 's/ /0/g;' | sed -e :a -e 's/^.\{1,47\}$/&0/;ta' | sed 's/../& /g'`
	echo "VLAN $VLAN:$VLANHEX PARA $IP"
	
	
	
	UNCFGONU
	if [ "$ROW" == "" ];then return 0; fi
	PORTACHASSISLOT $ROW
	CRIARONU
#	ONUID=$(CRIARONU)
	MODEL=$(MODELO)
	if [ "$MODEL" == "" ];then
		MODEL="F660"
	fi
	if [ "$MODEL" == "F660" ];then
		MODEL="F660_1"
	fi
	MODE="pppoe"

	echo "$CHASSI $PORTA $SLOT SERIAL: $SERIAL; PORTA_PON: $PORTAPON; ID: $ID; MODELO: $MODEL; MODO_OPERACAO: $MODE; BRIDGE_ID: $BRIDGEID"

	if [[ "$MODEL" == "F601" ]];then 
		MODE="dhcp"
		
	fi


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
		ZXGPON-SERVICE-MIB::zxGponOntRegMode.$ROW i 1 \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtTypeName.$ROW s ZTE-$MODEL \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtProvisionSn.$ROW x "0x$SERIAL" \
		ZXGPON-SERVICE-MIB::zxGponOntDevMgmtEntryStatus.$ROW i 4 

	if [ $? != 0 ];then 
		echo	snmpset -v2c -c $COMMUNITY $IP \
			ZXGPON-SERVICE-MIB::zxGponOntRegMode.$ROW i 1 \
			ZXGPON-SERVICE-MIB::zxGponOntDevMgmtTypeName.$ROW s ZTE-$MODEL \
			ZXGPON-SERVICE-MIB::zxGponOntDevMgmtProvisionSn.$ROW x "0x$SERIAL" \
			ZXGPON-SERVICE-MIB::zxGponOntDevMgmtEntryStatus.$ROW i 4 

		echo "OCORREU UM ERRO"; 
		exit; 
	fi

	#CONFIG TCONT
	display "CONFIGURANDO TCONT PARA A INTERFACE DA ONU"
	snmpset -v2c -c $COMMUNITY $IP \
		ZXGPON-SERVICE-MIB::zxOnuTrafficMgmtUnitName.$ROW.1 s 'Tcont100M_1' \
		ZXGPON-SERVICE-MIB::zxOnuTrafficMgmtUnitTcontUpBWIdxPtr.$ROW.1 i $TCONTID \
		ZXGPON-SERVICE-MIB::zxOnuTrafficMgmtUnitEntryStatus.$ROW.1 i 4 \

	#CONFIG TCONT
	display "CONFIGURANDO TCONT2 PARA A INTERFACE DA ONU"
	snmpset -v2c -c $COMMUNITY $IP \
		ZXGPON-SERVICE-MIB::zxOnuTrafficMgmtUnitName.$ROW.2 s 'Tcont100M_2' \
		ZXGPON-SERVICE-MIB::zxOnuTrafficMgmtUnitTcontUpBWIdxPtr.$ROW.2 i $TCONTID \
		ZXGPON-SERVICE-MIB::zxOnuTrafficMgmtUnitEntryStatus.$ROW.2 i 4 \
		
	if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

	display "CONFIGURANDO GEMPORT1 PARA A INTERFACE DA ONU"
	#CRIAR GEMPORT
	snmpset  -v2c -c $COMMUNITY $IP \
	ZXGPON-SERVICE-MIB::zxGponGemPortName.$ROW.1 s 'Gem1' \
	ZXGPON-SERVICE-MIB::zxGponGemPortType.$ROW.1 i 1 \
	ZXGPON-SERVICE-MIB::zxGponGemPortTcontIdx.$ROW.1 i 1 \
	ZXGPON-SERVICE-MIB::zxGponGemPortEntryStatus.$ROW.1 i 4 \

	#CRIAR GEMPORT 2
	snmpset  -v2c -c $COMMUNITY $IP \
	ZXGPON-SERVICE-MIB::zxGponGemPortName.$ROW.2 s 'Gem2' \
	ZXGPON-SERVICE-MIB::zxGponGemPortType.$ROW.2 i 1 \
	ZXGPON-SERVICE-MIB::zxGponGemPortTcontIdx.$ROW.2 i 2 \
	ZXGPON-SERVICE-MIB::zxGponGemPortEntryStatus.$ROW.2 i 4 \

	if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

	if [ "$MODE" == "pppoe" ];then
		display "CONFIGURANDO PPPoE NA INTERFACE pon-onu-mng"
		#HABILITAR O PPPOE
		snmpset  -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataNATEnable.$ROW.1 i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataMode.$ROW.1 i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataConnectTrigger.$ROW.1 i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataReleaseTimer.$ROW.1 i 1200 \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataUsername.$ROW.1 s $SERIAL_HUMAN \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataPassword.$ROW.1 s $SERIAL_HUMAN \
			ZXGPON-ONTMGMT-MIB::zxGponPPPoEConfigDataEntryStatus.$ROW.1 i 4
		if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi
		
		
		display "CONFIGURANDO DHCP NA INTERFACE pon-onu-mng 2"
		display "CONFIGURANDO DHCP NA INTERFACE pon-onu-mng"
		snmpset  -v2c -c $COMMUNITY $IP \
				ZXGPON-ONTMGMT-MIB::zxGponIPHostConfigDataIPOptions.$ROW.2 i 3 \
				ZXGPON-ONTMGMT-MIB::zxGponIPHostConfigDataOntIdentifier.$ROW.2 s $SERIAL_HUMAN 
		if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi
		
		
		
		
		#CRIAR O SERVICO
		display "CRIANDO O DATASERVICE PARA A VLAN"
		echo $ROW
		snmpset  -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponServiceName.$ROW.1 s 'dataservice1' \
			ZXGPON-ONTMGMT-MIB::zxGponServiceType.$ROW.1 i 5 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceGemPort.$ROW.1 i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceMapType.$ROW.1 i 2 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceMapVlan.$ROW.1 x "0x$VLANHEX" \
			ZXGPON-ONTMGMT-MIB::zxGponServiceIfId.$ROW.1 i 131073 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceEntryStatus.$ROW.1 i 4 
			
	if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi
	
	
	display "CRIANDO O DATASERVICE2 PARA A VLAN"
snmpset  -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponServiceName.$ROW.2 s 'dataservice2' \
			ZXGPON-ONTMGMT-MIB::zxGponServiceType.$ROW.2 i 5 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceGemPort.$ROW.2 i 2 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceMapType.$ROW.2 i 2 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceMapVlan.$ROW.2 x "0x$VLANHEX_TR" \
			ZXGPON-ONTMGMT-MIB::zxGponServiceIfId.$ROW.2 i 131074 \
			ZXGPON-ONTMGMT-MIB::zxGponServiceEntryStatus.$ROW.2 i 4 		
	
	if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

			
		
		
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
	
	#CALCULAR O BRIDGEID TYPE 4 INDEX
	#|  4     |  4      |          8        |        8          |         8         |
	#|Type: 4 |  Shelf  | Cardid(5b)Olt(3b) |       Onu         | Vport/SrvPortId   |
	BRIDGEID="0100"
	CHASSI=`expr $CHASSI - 1 `
	S=`echo "obase=2;$CHASSI" | bc | awk '{printf "%04s\n", $0}'| sed 's/ /0/g;'`
	if [[ $SLOT -ge 2 && $SLOT -le 9 ]];then
		SLOT=`expr $SLOT - 2 `
	elif [[ $SLOT -ge 12 && $SLOT -le 22 ]];then
		SLOT=`expr $SLOT - 4`
	else
		SLOT=0
	fi
	C=`echo "obase=2;$SLOT" | bc | awk '{printf "%05s\n", $0}' | sed 's/ /0/g;'`
	
	PORTA=`expr $PORTA - 1 | sed 's/ /0/g;'`
	O=`echo "obase=2;$PORTA" | bc | awk '{printf "%03s\n", $0}'| sed 's/ /0/g;'`
	ID=`expr $ID - 1 `
	U=`echo "obase=2;$ID" | bc | awk '{printf "%08s\n", $0}'| sed 's/ /0/g;'`
	V=`echo "obase=2;0" | bc | awk '{printf "%08s\n", $0}'| sed 's/ /0/g;'`
	V2=`echo "obase=2;1" | bc | awk '{printf "%08s\n", $0}'| sed 's/ /0/g;'`

	echo "$C:$PORTA:$O:$ID:$U:$V"
	echo "0100:$S:$C:$O:$U:$V"
	BRIDGEID=`echo "obase=10;ibase=2;0100$S$C$O$U$V" | bc`
	BRIDGEID2=`echo "obase=10;ibase=2;0100$S$C$O$U$V2" | bc`
	
	
	display "CRIANDO A SERVICE PORT: $BRIDGEID: $CHASSI/$SLOT/$PORTA:$ID"
	snmpset  -v2c -c $COMMUNITY $IP \
			ZTE-AN-SERVICEPORT::zxAnServicePortDesc.$BRIDGEID.1 s "$SERIAL_HUMAN" \
			ZTE-AN-SERVICEPORT::zxAnServicePortServiceMode.$BRIDGEID.1 i 4 \
			ZTE-AN-SERVICEPORT::zxAnUserInVid.$BRIDGEID.1 i $VLAN \
			ZTE-AN-SERVICEPORT::zxAnUserInPriority.$BRIDGEID.1 i 0 \
			ZTE-AN-SERVICEPORT::zxAnUserEthType.$BRIDGEID.1 i 1 \
			ZTE-AN-SERVICEPORT::zxAnUserEthFilter.$BRIDGEID.1 i 2 \
			ZTE-AN-SERVICEPORT::zxAnUserOutCVid.$BRIDGEID.1 i $VLAN \
			ZTE-AN-SERVICEPORT::zxAnVlanTransMode.$BRIDGEID.1 i 1

	if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi

	display "CRIANDO A SERVICE PORT 2: $BRIDGEID: $CHASSI/$SLOT/$PORTA:$ID"
	snmpset  -v2c -c $COMMUNITY $IP \
			ZTE-AN-SERVICEPORT::zxAnServicePortDesc.$BRIDGEID2.2 s "$SERIAL_HUMAN" \
			ZTE-AN-SERVICEPORT::zxAnServicePortServiceMode.$BRIDGEID2.2 i 4 \
			ZTE-AN-SERVICEPORT::zxAnUserInVid.$BRIDGEID2.2 i $VLAN_TR \
			ZTE-AN-SERVICEPORT::zxAnUserInPriority.$BRIDGEID2.2 i 0 \
			ZTE-AN-SERVICEPORT::zxAnUserEthType.$BRIDGEID2.2 i 2 \
			ZTE-AN-SERVICEPORT::zxAnUserEthFilter.$BRIDGEID2.2 i 2 \
			ZTE-AN-SERVICEPORT::zxAnUserOutCVid.$BRIDGEID2.2 i $VLAN_TR \
			ZTE-AN-SERVICEPORT::zxAnVlanTransMode.$BRIDGEID2.2 i 1

	if [ $? != 0 ];then echo "OCORREU UM ERRO";ROLLBACK; exit; fi
	
	
	

}



function ATIVARTELEFONE {
			CONTASIP=$1
			SENHASIP=$2
			IDXLINHA=$3
			ROW=$4
		  display "CONFIGURANDO CONTA SIP"
		  #DETERMINA O VOIP PROTOCOL
		  snmpset -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponVoIPConfigDataSignalProtocolUsed.$ROW.$IDXLINHA i 2
		
		   snmpset  -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataProxyServer.$ROW.$IDXLINHA s fs.voice.valenet.com.br \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataOutboundProxy.$ROW.$IDXLINHA s fs.voice.valenet.com.br \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataPrimaryDNS.$ROW.$IDXLINHA a 177.152.174.13 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataSecondaryDNS.$ROW.$IDXLINHA a 177.152.174.14 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataUDPTCPPort.$ROW.$IDXLINHA i 5060 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataHostId.$ROW.$IDXLINHA i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataRegExpTime.$ROW.$IDXLINHA i 3600 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataReRegStartTime.$ROW.$IDXLINHA i 360 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataRegServer.$ROW.$IDXLINHA s fs.voice.valenet.com.br \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataValidatScheme.$ROW.$IDXLINHA i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPAgentConfigDataEntryStatus.$ROW.$IDXLINHA i 4
		
		   snmpset -v2c -c $COMMUNITY $IP \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataAgentId.$ROW.$IDXLINHA i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataUserPartAOR.$ROW.$IDXLINHA s $CONTASIP \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataDisplayName.$ROW.$IDXLINHA s $CONTASIP \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataUserName.$ROW.$IDXLINHA s $CONTASIP \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataPassword.$ROW.$IDXLINHA s $SENHASIP \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailServerURI.$ROW.$IDXLINHA s '' \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailValidateScheme.$ROW.$IDXLINHA i 1 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailUserName.$ROW.$IDXLINHA s '' \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailPassword.$ROW.$IDXLINHA s '' \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailRealm.$ROW.$IDXLINHA s '' \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataVMailSubsciptExpTime.$ROW.$IDXLINHA i 3600 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataNetworkDialPlanPtr.$ROW.$IDXLINHA i 0 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataServiceProfilePtr.$ROW.$IDXLINHA i 0 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataFeatureCodePtr.$ROW.$IDXLINHA i 0 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataReleaseTimer.$ROW.$IDXLINHA i 10 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataROHTimer.$ROW.$IDXLINHA i 15 \
			ZXGPON-ONTMGMT-MIB::zxGponSIPUserDataEntryStatus.$ROW.$IDXLINHA i 4 

}

function BUSCARONU {
	snmpwalk -v2c -c VALENETZTE $IP .1.3.6.1.4.1.3902.1012.3.28.1.1.5 | awk  '{print $1".ZTEG"$8$9$10$11}' | grep -i "$1" | cut -d "." -f 2,3
}








#pausa
#CADASTRARONU
#ROLLBACK