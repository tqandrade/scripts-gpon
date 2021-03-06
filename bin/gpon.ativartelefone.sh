#!/bin/bash

. /usr/local/bin/include.sh
export PYTHONIOENCODING=utf8
if [ "$1" == "auto" ];then
echo "BUSCANDO ARQUIVOS"
for f in $(ls /var/spool/telefone/*.json | grep -v \~);do
	IP=$(cat $f | python -c "import sys, json; print json.load(sys.stdin)['OLT']")
	SN=$(cat $f | python -c "import sys, json; print json.load(sys.stdin)['SN']")
	CONTA1=$(cat $f | python -c "import sys, json; print json.load(sys.stdin)['CONTA1']")
	SENHA1=$(cat $f | python -c "import sys, json; print json.load(sys.stdin)['SENHA1']")
	CONTA2=$(cat $f | python -c "import sys, json; print json.load(sys.stdin)['CONTA2']")
	SENHA2=$(cat $f | python -c "import sys, json; print json.load(sys.stdin)['SENHA2']")
#	MONGOID=$(mongo 192.168.0.105:27017/genieacs --eval "print(db.getCollection('devices').find({_id: /.*3B08EE7F/}, {_id:1}).toArray()[0]._id);" | tail -1 | grep "-")

#	curl -i "http://192.168.0.105:7557/devices/$MONGOID/tasks?timeout=3000&connection_request" -X POST --data "{ \"name\": \"setParameterValues\", \"parameterValues\": [[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.AuthUserName\",\"$CONTA1\"],[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.AuthPassword\",\"$SENHA1\"],[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.Codec.List.3.Enable\",\"true\"],[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.Codec.List.2.Enable\",\"true\"],[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.SIP.ProxyServer\",\"fs.voice.valenet.com.br\",\"fs.voice.valenet.com.br\"],[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.SIP.OutboundProxy\",\"fs.voice.valenet.com.br\"]]}"
#	if [ "$CONTA2" != "" ];then
#		curl -i "http://192.168.0.105:7557/devices/$MONGOID/tasks?timeout=3000&connection_request" -X POST --data "{ \"name\": \"setParameterValues\", \"parameterValues\": [[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.AuthUserName\",\"$CONTA2\"],[\"InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.AuthPassword\",\"$SENHA2\"]]}"

#	fi
#	pos_ativacao.js $f
	echo "pos_ativacao.js $f"
	
	ROWID=$(BUSCARONU $SN)
	
	echo $ROWID
#	
	if [ "$ROWID" != "" ];then
		ATIVARTELEFONE $CONTA1 $SENHA1 1 $ROWID
		if [ "$CONTA2" != "" ];then
			ATIVARTELEFONE $CONTA2 $SENHA2 2 $ROWID
		fi
	fi
	
	mkdir -p /var/spool/telefone/processed
	mv $f /var/spool/telefone/processed/
done

else
	IP=$1
	SN=$2
	CONTA1=$3
	SENHA1=$4
	
	if [ "$SENHA1" == "" ];then
		echo "USAGE: $0 IP_OLT SERIAL_ONU CONTASIP SENHASIP"
		exit 0
	fi
	ROWID=$(BUSCARONU $SN)
	echo $ROWID
#	
	if [ "$ROWID" != "" ];then
		ATIVARTELEFONE $CONTA1 $SENHA1 1 $ROWID
		if [ "$CONTA2" != "" ];then
			ATIVARTELEFONE $CONTA2 $SENHA2 2 $ROWID
		fi
	fi
	
	
fi

#echo $f
#	. $f
#	IP=$OLT
#	echo $SN

echo "FIM"


