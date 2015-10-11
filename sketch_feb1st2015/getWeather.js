// poll the weather service
// look for sunshine, clouds, rain, alerts, night and day
var http = require('https');
var fs = require('fs');
var weatherUrl = "https://api.forecast.io/forecast/1ad1d6da386ef3030cd590230a58a29a/51.540001,-0.147519?exclude=currently,minutely,hourly,flags&units=auto";
var finished = false;
var data = "";
var waitedCount = 0;

const outputFilename = "./index.txt";

var clientRequest = http.get(weatherUrl).on('error', function(e) {
	console.log("Got error: " + e.message);
	finished = true;
});

clientRequest.on('response', function(res2) {
	res2.on('data', function (chunk) {
		// console.log("chunk : "+chunk);
	  data += chunk;
	}).on('end', function() {
		// console.log("finished : "+data);
		finished = true;
	});
});

function waitToFinish() {
	if (finished) {
		finish();
	} else {
		// sleep(1);
		// console.log("setTimeout" + finished);
		setTimeout(function() {
		  // console.log('This will still run.');
		  waitedCount++
		  if (waitedCount < 100) {
			  waitToFinish();
		  } else {
		  	console.log("TIMEOUT!!!");
		  }
		  // console.log(data);
		},100);
	}
}

function finish() {
	// console.log("data : "+data);
	var weather = JSON.parse(data);
	// console.log(weather);
	var alerts = weather.alerts;
	var today = weather.daily.data[0];
	// console.log(JSON.stringify(today));
	// console.log(alerts);
	// console.log('finished function');
	var cloudCover = today.cloudCover;
	var pp = today.precipProbability;
	var sunrise = today.sunriseTime;
	var sunset = today.sunsetTime;

	var isCloudy = cloudCover > 0.5 ? "1" : "0";
	var isSunny = cloudCover < 0.7 ? "1" : "0";
	var willRain = pp > 0.1 ? "1" : "0";
	var alert = alerts != undefined ? "1" : "0";
	var now = Math.floor(Date.now() / 1000);
	var daytime = now > sunrise && now < sunset;
	var moon = (isSunny == "1" && daytime)  ? "1" : "0";
	var flashSun = "0"; // future expansion

	var output = isCloudy + isSunny + willRain + alert + moon + flashSun;
	console.log(output);

	fs.writeFileSync(outputFilename,output);
}

waitToFinish();