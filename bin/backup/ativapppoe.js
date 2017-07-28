#!/usr/bin/env node
var program = require('commander');
program
.version('0.1.0')
  .option('-s, --serial <serialnumber>', 'Serial da ONU a ativar')
  .parse(process.argv);


console.log(program.serial);


var MongoClient = require('mongodb').MongoClient;
var url = "mongodb://localhost:27017/genieacs";

MongoClient.connect(url, function(err, db) {
  if (err) throw err;
  db.collection('devices').findOne({_id: new RegExp(program.serial.substr(4)+'$', 'i')},function(err, result) {
    if (err) throw err;
    console.log(result._id);
	
	
    db.close();
  });
});