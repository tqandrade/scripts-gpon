#!/usr/bin/env node
var program = require('commander');
var querystring = require('querystring');
var fs = require('fs');
var MongoClient = require('mongodb').MongoClient;

var urlMongo = "mongodb://localhost:27017/genieacs";
var genieHostName = "localhost";
var geniePort = 7557;



program
.version('0.1.0')
  .option('-f, --file <parametros>', 'Arquivo JSON com os parâmetros')
  .parse(process.argv);
  

if (program.file == null) process.exit();

//carrega o arquivo de parametros
var obj = JSON.parse(fs.readFileSync(program.file, 'utf8'));


//todo: corrigir carregamento da vlan
var vlan=2121;

//constroi o objeto de post
var postObj =	{ name: "setParameterValues", 
	parameterValues: 
	[
		["InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.AuthUserName",obj.CONTA1],
		["InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.SIP.AuthPassword",obj.SENHA1],
		["InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.Codec.List.3.Enable","true"],
		["InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.Line.1.Codec.List.2.Enable","true"],
		["InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.SIP.ProxyServer","fs.voice.valenet.com.br"],
		["InternetGatewayDevice.Services.VoiceService.1.VoiceProfile.1.SIP.OutboundProxy","fs.voice.valenet.com.br"],
		["InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.X_CT-COM_WANGponLinkConfig.VLANIDMark",vlan],
		["InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.Username",obj.SN],
		["InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.Password",obj.SN],
		["InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANPPPConnection.1.Name", "1_INTERNET_R_VID_"+vlan]
	]
	};















MongoClient.connect(urlMongo, function(err, db) {
  if (err) throw err;
  db.collection('devices').findOne({_id: new RegExp(obj.SN.substr(4)+'$', 'i')},function(err, result) {
    if (err) throw err;
    
	postToGenie(postObj, result._id);
	
    db.close();
  });
});


function postToGenie(obj, mongoId){
	var http = require('http');
	var postData = JSON.stringify(obj);
	
	var options = {
	  hostname: genieHostName,
	  port: geniePort,
	  path: '/devices/'+mongoId+'/tasks?timeout=3000&connection_request',
	  method: 'POST', // <--- aqui podes escolher o método
	  headers: {
		'Content-Type': 'application/x-www-form-urlencoded',
		'Content-Length': Buffer.byteLength(postData)
	  }
	};

	var req = http.request(options, (res) => {
	  res.setEncoding('utf8');
	  var data = '';
	  res.on('data', d => data += d);
	  res.on('end', () => {
		console.log('Concluido!');
	  });
	});

	req.on('error', (e) => {
	  console.log(`Houve um erro: ${e.message}`);
	});

	// aqui podes enviar data no POST
	req.write(postData);
	req.end();
	
}