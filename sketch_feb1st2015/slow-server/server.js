var express = require('express');
var app = express();
var server = require('http').createServer(app);

app.get('/weather/index.html',function(req,res) {
    res.end('0101');
/*
  setTimeout(function(){
    res.end('0101');
  }, 10);
*/
});

server.listen(3000);
