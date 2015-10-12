var express = require('express');
var fs = require('fs');
app = express();
app.listen(3000);
console.log('started server on 3000');

app.use(express.static('public'));

app.get('/weather/',function(req,res) {
  res.redirect('/index.txt');
  //res.send('Good night <h2>Eli Kay</h2>');
});

app.get('/weather.txt',function(req,res) {
	res.useChunkedEncodingByDefault = false;
	res.removeHeader("Connection");
	res.removeHeader("Date");
	res.removeHeader("X-Powered-By");
	res.removeHeader("Content-Length");
	var weather = fs.readFileSync('weather.txt')
	res.end(weather);
});