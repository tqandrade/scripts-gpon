#!/usr/bin/env node
var http = require('http');
var options = {
  host: 'viacep.com.br' ,
  port: 80,
  path: '/ws/01001000/json/',
  method: 'POST'
};

http.request(options, function(res) {
  console.log('STATUS: ' + res.statusCode);
  console.log('HEADERS: ' + JSON.stringify(res.headers));
  res.setEncoding('utf8');
  res.on('data', function (chunk) {
    console.log('BODY: ' + chunk);
  });
}).end();