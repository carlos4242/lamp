#! /usr/bin/php
<?php

function curl_get_weather($url) {
    if (!function_exists('curl_init')){
        die('Sorry cURL is not installed!');
    }
 
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://api.forecast.io/forecast/1ad1d6da386ef3030cd590230a58a29a/51.540001,-0.147519?exclude=currently,minutely,hourly,flags&units=auto");
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 2);
    $output = curl_exec($ch);
    curl_close($ch);
    return $output;
}

$weather_url = "https://api.forecast.io/forecast/1ad1d6da386ef3030cd590230a58a29a/51.540001,-0.147519?exclude=currently,minutely,hourly,flags&units=auto";
$raw = curl_get_weather($weather_url);
$weather = json_decode($raw,true);
$alerts = $weather["alerts"];

$today = $weather["daily"]["data"][0];
$cloudCover = $today["cloudCover"];
$cloudCover = $today["cloudCover"];
$precipProbability = $today["precipProbability"];
$sunrise = $today["sunriseTime"];
$sunset = $today["sunsetTime"];

$cloudIcon = $cloudCover > 0.5 ? 1 : 0;
$sunIcon = $cloudCover < 0.7 ? 1 : 0;
$rainIcon = $precipProbability > 0.1 ? 1 : 0;
$alertIcon = $alerts ? 1 : 0; 

// $now = time();
#$dayIcon = $now > $sunrise && $now < $sunset ? 1 : 0;

file_put_contents("/Library/WebServer/Documents/weather/index.html",$cloudIcon.$sunIcon.$rainIcon.$alertIcon);
$detail = array();
$detail["source"] = $weather_url;
$detail["alerts"] = $alerts;
$detail["today"] = $today;
$detail["daily"] = $weather["daily"];
file_put_contents("/Library/WebServer/Documents/weather/raw.html",json_encode($detail));

?>