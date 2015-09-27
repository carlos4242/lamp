#include <Ethernet.h>
#include <avr/wdt.h>
#include <avr/pgmspace.h>
#include <EEPROM.h>
#include "errno.h"
#include <utility/w5100.h>
#include <ADCTouch.h>
// sourced from https://github.com/Megunolink/ArduinoCrashMonitor
// referenced by http://www.megunolink.com/how-to-detect-lockups-using-the-arduino-watchdog/
#include <ApplicationMonitor.h>

#define enable_serial_debug 1

#ifdef enable_serial_debug
#include <SPI.h>
#define DEBUG_OUT(param) Serial.println(param)
#else
#define DEBUG_OUT(param)
#endif

/*
 *
 *  GLOBAL STATE AREA
 *
 */

// Watchdog dump class
Watchdog::CApplicationMonitor ApplicationMonitor;

// Initialize the Ethernet server library
// with the IP address and port you want to use
// (port 80 is default for HTTP):
EthernetServer server(80);

// light control
byte lightOne =  8;
byte lightTwo = 9;
byte lightThree = 7;

// touch sensor
int ref0, ref1, ref2;       //reference values to remove offset

// weather display
byte cloudIcon = 6;
byte sunIcon = 5;
byte rainLamp = 3;

byte alertSavingState = 14;

// weather state
boolean alertActiveState;
boolean cloudIconState;
boolean sunIconState;
boolean rainLampState;
int timer1_counter;

// state flags :
boolean lightOneState;
boolean lightTwoState;
boolean lightThreeState;
boolean debug = false;

volatile unsigned int interruptCounter = 0;
byte currentRainLampBrightness = 0;




/*
 *
 *  SETUP
 *
 */


void setup()   {
  // setup pins :
  pinMode(lightOne, OUTPUT);
  pinMode(lightTwo, OUTPUT);
  pinMode(lightThree, OUTPUT);
  pinMode(cloudIcon, OUTPUT);
  pinMode(sunIcon, OUTPUT);
  pinMode(rainLamp, OUTPUT);

  // setup touch sensor
  // This is from here : http://playground.arduino.cc/Code/ADCTouch
  ref0 = ADCTouch.read(A0, 500);    //create reference values to
  ref1 = ADCTouch.read(A1, 500);      //account for the capacitance of the pad
  ref2 = ADCTouch.read(A2, 500);      //account for the capacitance of the pad

  // setup serial :
  Serial.begin(9600);

  // assign a MAC and IP addresses for the ethernet controller :
  byte mac[] = {
    0x90, 0xA2, 0xDA, 0x0D, 0x9C, 0x31
  };
  IPAddress ip(10, 0, 1, 160);
  Ethernet.begin(mac, ip);

  // shorten timeout
  W5100.setRetransmissionTime(0x3E8);
  W5100.setRetransmissionCount(1);

  // restore light state from eeprom :
  lightOneState = EEPROM.read(lightOne);
  lightTwoState = EEPROM.read(lightTwo);
  lightThreeState = EEPROM.read(lightThree);
  setLines();

  cloudIconState = EEPROM.read(cloudIcon);
  sunIconState = EEPROM.read(sunIcon);
  rainLampState = EEPROM.read(rainLamp);
  alertActiveState = EEPROM.read(alertSavingState);
  setWeatherLamps();

  // initialize timer1
  // (credit http://www.hobbytronics.co.uk/arduino-timer-interrupts,
  // nod to http://www.avrbeginners.net/architecture/timers/timers.html)
  noInterrupts();           // disable all interrupts
  TCCR1A = 0;
  TCCR1B = 0;

  // Set timer1_counter to the correct value for our interrupt interval
  //timer1_counter = 64886;   // preload timer 65536-16MHz/256 == 96.1538Hz
  //timer1_counter = 64286;   // preload timer 65536-16MHz/256 == 50Hz
  //  timer1_counter = 34286;   // preload timer 65536-16MHz/256 == 2HzM

  timer1_counter = 62411;   // preload timer 65536-16MHz/256 == 20HzM

  TCNT1 = timer1_counter;   // preload timer
  TCCR1B |= (1 << CS12);    // 256 prescaler
  TIMSK1 |= (1 << TOIE1);   // enable timer overflow interrupt
  interrupts();             // enable all interrupts

  // start the watchdog timer :
  ApplicationMonitor.Dump(Serial);
  ApplicationMonitor.EnableWatchdog(Watchdog::CApplicationMonitor::Timeout_4s);
  //wdt_enable(WDTO_4S); // have the wdt reset the chip

  // start the ethernet server :
  server.begin();

  DEBUG_OUT(F(">>Started"));
}




/*
 *
 *  INTERRUPT HANDLER
 *
 */

#define rainLampMin 10
#define rainLampMax 255
#define rainLampHalfCycleTime 0.7
#define secondsPerInterrupt 0.05

ISR(TIMER1_OVF_vect)
{
  // interrupt service routine
  // handles setting flags for other processing (e.g. network connection timeouts)
  // and pulsing the warning lamp
  static const byte stepsPerHalfCycle = byte(float(rainLampMax - rainLampMin) / (rainLampHalfCycleTime / secondsPerInterrupt));
  static boolean waxing = true;

  TCNT1 = timer1_counter;   // preload timer
  interruptCounter++;
  if (alertActiveState) {
    if (waxing) {
      currentRainLampBrightness += stepsPerHalfCycle;
      if (currentRainLampBrightness >= rainLampMax) {
        currentRainLampBrightness = rainLampMax;
        waxing = false;
      }
    }
    else {
      currentRainLampBrightness -= stepsPerHalfCycle;
      if (currentRainLampBrightness <= rainLampMin) {
        currentRainLampBrightness = rainLampMin;
        waxing = true;
      }
    }
    analogWrite(rainLamp, currentRainLampBrightness);
  }
}






/*
 *
 *  WEATHER CHECKING
 *
 */



void getLatestWeather() {
  static EthernetClient weatherClient;
  static const byte weatherServerAddress[] = {
    10, 0, 1, 102
  };
  static const int weatherBufferLen = 10;
  static char weatherBuffer[weatherBufferLen];

  static int lineLength = 0;
  static boolean readingWeatherReply = false;
  static boolean finish = false;

  if (interruptCounter >= 60) {
    // poll weather
    boolean connectStatusCode = weatherClient.connect(weatherServerAddress, 80);
    if (connectStatusCode) {
      weatherClient.println(F("GET /weather/"));
      weatherClient.println();
      int lineLength = 0;
      readingWeatherReply = true;
    }
    interruptCounter = 0;
    finish = false;
    lineLength = 0;
  }

  if (interruptCounter > 20) {
    // reset/abort timeout
    if (readingWeatherReply) {
      DEBUG_OUT(F("reset weather connection"));
      lineLength = 0;
      finish = true;
    }
  }
  if (readingWeatherReply) {
    if (weatherClient.connected()) {
      if (weatherClient.available()) {
        weatherBuffer[lineLength] = weatherClient.read();
        lineLength++;
      }
    }
    else {
      finish = true;
    }
  }
  if (finish) {
    readingWeatherReply = false;
    weatherBuffer[lineLength] = 0;
    weatherClient.stop();
    weatherClient.flush();
    decodeWeather(weatherBuffer);
    finish = false;
  }
}

void decodeWeather(char * weather) {
  boolean oldRainLampState = rainLampState;
  boolean oldAlertActiveState = alertActiveState;
  cloudIconState = weather[0] - 48;
  sunIconState = weather[1] - 48;
  rainLampState = weather[2] - 48;
  alertActiveState = weather[3] - 48;
  if (alertActiveState != oldAlertActiveState) {
    currentRainLampBrightness = oldRainLampState ? 255 : 0;
  }
  setWeatherLamps();
}

void setWeatherLamps() {
  digitalWrite(cloudIcon, cloudIconState);
  digitalWrite(sunIcon, sunIconState);
  if (!alertActiveState) {
    digitalWrite(rainLamp, rainLampState);
  }

  EEPROM.write(cloudIcon, cloudIconState);
  EEPROM.write(sunIcon, sunIconState);
  EEPROM.write(rainLamp, rainLampState);
  EEPROM.write(alertSavingState, alertActiveState);
}






/*
 *
 *  TOUCH SENSOR
 *
 */



void checkTouchSensor() {
  static boolean sensor1BeingTouched = false;
  static boolean sensor2BeingTouched = false;
  static boolean sensor3BeingTouched = false;

  int value0 = ADCTouch.read(A0);   //no second parameter
  int value1 = ADCTouch.read(A1);     //   --> 100 samples
  int value2 = ADCTouch.read(A2);     //   --> 100 samples

  value0 -= ref0;       //remove offset
  value1 -= ref1;
  value2 -= ref2;

  if (value0 > 40) {
    if (!sensor1BeingTouched) {
      if (lightOneState == HIGH) {
        // one of the lights is off, turn all on
        allOn();
      }
      else {
        // one of the lights is on, turn corner only
        cornerOnly();
      }
      setLines();
    }
    sensor1BeingTouched = true;
  }
  else {
    sensor1BeingTouched = false;
  }

  if (value1 > 40) {
    if (!sensor2BeingTouched) {
      allOff();
      setLines();
    }
    sensor2BeingTouched = true;
  }
  else {
    sensor2BeingTouched = false;
  }

  if (value2 > 40) {
    if (!sensor3BeingTouched) {
    }
    sensor3BeingTouched = true;
  }
  else {
    sensor3BeingTouched = false;
  }
}





/*
 *
 *  SERIAL PORT DEBUGGING
 *
 */



// report status on serial port
void report() {
  DEBUG_OUT(statusString());
}

void readSerialCommands() {
  if (Serial.available() > 0) {
    // read the incoming byte:
    int incomingByte = Serial.read();
    if (incomingByte == 97) { // a
      lightOneState = HIGH;
      setLines();
      report();
    }
    else if (incomingByte == 98) { // b
      lightOneState = LOW;
      setLines();
      report();
    }
    else if (incomingByte == 99) { // c
      lightTwoState = HIGH;
      setLines();
      report();
    }
    else if (incomingByte == 100) { // d
      lightTwoState = LOW;
      setLines();
      report();
    }
    else if (incomingByte == 101) { // e
      lightThreeState = HIGH;
      setLines();
      report();
    }
    else if (incomingByte == 102) { // f
      lightThreeState = LOW;
      setLines();
      report();
    }
    else if (incomingByte == 48) { // 0
      allOff();
      setLines();
      report();
    }
    else if (incomingByte == 49) { // 1
      allOn();
      setLines();
      report();
    }
    else if (incomingByte == 115) { // s
      report();
    }
    else if (incomingByte == 68) { // D - debug toggle
      debug = !debug;
      if (debug) {
        DEBUG_OUT(F("http debug on"));
      }
      else {
        DEBUG_OUT(F("http debug off"));
      }
    }
  }
}






/*
 *
 *  MAIN LOOP
 *
 */


void loop()
{
  readSerialCommands();
  checkTouchSensor();
  getLatestWeather();
  runWebServer();
  ApplicationMonitor.IAmAlive();
}








/*
 *
 *  HTTP SERVER and WEB Service handling
 *
 */


// GET /   ... get web code
// GET /lights   ... get json of lights status
// GET /lights/light1   ...   get json of single light status
// POST /lights  ...  allOn=1 ... turn all lights on and return json of lights status
// POST /lights  ...  allOff=1 ... turn all lights off and return json of lights status
// POST /lights/light2  ...  on=x  ... turn lights on or off (1 and 0 are only recognized values) returns json of single light status

// state (interpreted from the request line)

int lightToSet = 0;
boolean sendFavicon;
boolean sendWebsite;
char * (*postFunction)(const char * postBody);

// useful functions

char * statusString() {
  static const int statusBufferLen = 19;
  static char statusBuffer[statusBufferLen];
  strncpy(statusBuffer, "{\"1\":X,\"2\":X,\"3\":X}", statusBufferLen);
  statusBuffer[5] = 48 + lightOneState; //
  statusBuffer[11] = 48 + lightTwoState;
  statusBuffer[17] = 48 + lightThreeState;
  return statusBuffer;
}

void setLines() {
  digitalWrite(lightOne, lightOneState);
  digitalWrite(lightTwo, lightTwoState);
  digitalWrite(lightThree, lightThreeState);

  EEPROM.write(lightOne, lightOneState);
  EEPROM.write(lightTwo, lightTwoState);
  EEPROM.write(lightThree, lightThreeState);
}

void allOn() {
  lightOneState = LOW;
  lightTwoState = LOW;
  lightThreeState = LOW;
}

void allOff() {
  lightOneState = HIGH;
  lightTwoState = HIGH;
  lightThreeState = HIGH;
}

void cornerOnly() {
  lightOneState = HIGH;
  lightTwoState = HIGH;
  lightThreeState = LOW;
}

char * getLightStatus(int light) {
  int lightStatus;
  if (light == 1) {
    lightStatus = lightOneState;
  }
  else if (light == 2) {
    lightStatus = lightTwoState;
  }
  else if (light == 3) {
    lightStatus = lightThreeState;
  }
  else {
    return "invalid";
  }

  static const int statusBufferLen = 10;
  static char statusBuffer[statusBufferLen];

  char * buffer = statusBuffer;

  strncpy(buffer, "{\"", 2);
  buffer += 2;
  *buffer = 48 + light;
  buffer += 1;
  strncpy(buffer, "\":X}", 5);
  buffer[2] = 48 + lightStatus;
  return statusBuffer;
}

char * getLightsStatus() {
  return statusString();
}

char * changeLightStatus(const char * postBody) {
  static const char * onSwitchParam = "on=";
  // use light to define which light is affected and postData to define how it's affected
  int lightSwitchValue;
  if (strncmp(postBody, onSwitchParam, strlen(onSwitchParam)) == 0) {
    const char * lightSwitchValueString = postBody + strlen(onSwitchParam);
    lightSwitchValue = atoi(lightSwitchValueString);
  }
  else {
    return "invalid";
  }
  if (lightToSet == 1) {
    lightOneState = lightSwitchValue;
    setLines();
    return getLightsStatus();
  }
  else if (lightToSet == 2) {
    lightTwoState = lightSwitchValue;
    setLines();
    return getLightsStatus();
  }
  else if (lightToSet == 3) {
    lightThreeState = lightSwitchValue;
    setLines();
    return getLightsStatus();
  }
  else {
    return "invalid";
  }
}

char * changeLightsStatus(const char * postBody) {
  static const char * allOnParam = "allOn=1";
  static const char * allOffParam = "allOff=1";

  // use postData to define command
  if (strncmp(postBody, allOnParam, strlen(allOnParam)) == 0) {
    allOn();
    setLines();
    return getLightsStatus();
  }
  else if (strncmp(postBody, allOffParam, strlen(allOffParam)) == 0) {
    allOff();
    setLines();
    return getLightsStatus();
  }
  else {
    return "invalid";
  }
}

char * readRequestLine(const char * requestLine) {
  static const char * getLightsString = "GET /lights";
  static const char * getLightString = "GET /lights/";
  static const char * getFavicon = "GET /favicon";
  static const char * getWebsite = "GET /";
  static const char * postLightsString = "POST /lights";
  static const char * postLightString = "POST /lights/";

  if (strncmp(requestLine, getLightString, strlen(getLightString)) == 0) {
    // get the status of a single light
    return getLightStatus(atoi(requestLine + strlen(getLightString)));
  }
  else if (strncmp(requestLine, getLightsString, strlen(getLightsString)) == 0) {
    // get the status of all lights
    return getLightsStatus();
  }
  else if (strncmp(requestLine, getFavicon, strlen(getFavicon)) == 0) {
    // send the favicon
    sendFavicon = true;
    return 0;
  }
  else if (strncmp(requestLine, postLightString, strlen(postLightString)) == 0) {
    // set the status of a light
    lightToSet = atoi(requestLine + strlen(postLightString));
    postFunction = changeLightStatus;
    return 0;
  }
  else if (strncmp(requestLine, postLightsString, strlen(postLightsString)) == 0) {
    postFunction = changeLightsStatus;
    return 0;
  }
  else if (strncmp(requestLine, getWebsite, strlen(getWebsite)) == 0) {
    // send the website
    sendWebsite = true;
    return 0;
  }
  else {
    if (debug) {
      // this is a dodgy http request
      DEBUG_OUT(F("Invalid http request"));
      DEBUG_OUT(requestLine);
    }
    return 0;
  }
}

void writeWebServiceReply(EthernetClient client, const char * output) {
  static const char * header = "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n";
  static const int headerLength = strlen(header);
  static char htmlReply[100];
  char * htmlReplyPointer = htmlReply;
  strncpy(htmlReplyPointer, header, headerLength);
  htmlReplyPointer += headerLength;
  int outputLength = strlen(output);
  strncpy(htmlReplyPointer, output, outputLength);
  htmlReplyPointer += outputLength;
  int htmlReplyLength = htmlReplyPointer - htmlReply;
  client.write((byte*)htmlReply, htmlReplyLength);
}

static boolean firstLine = true;
static boolean gotHeaders = false;
static boolean postDataRead = false;
static boolean finishedReadingLine = false;
static char * output = 0;
static int lineLength = 0;

void cleanupWebServer() {
  sendFavicon = false;
  sendWebsite = false;
  firstLine = true;
  gotHeaders = false;
  postDataRead = false;
  finishedReadingLine = false;
  output = 0;
  postFunction = 0;
  lineLength = 0;
}

void runWebServer() {
  static EthernetClient client = NULL;
  static const int lineBufferLen = 200;
  static char lineBuffer[lineBufferLen];

  if (client) {
    // we have a client, fill up the buffers with data
    if (client.connected()) {
      if (gotHeaders) {
        // if we have already got the headers, the line we are receiving may be POST body data and may not end with a \n
        // so we should carry on reading bytes into the buffer until there are none left
        // the whole POST data will then be in the "line" buffer, which might actually have multiple lines in
        if (client.available()) {
          if (lineLength < lineBufferLen) { // check for buffer overrun
            lineBuffer[lineLength] = client.read();
            lineLength++;
          } else {
            // we have a buffer overrun somehow, reset the connection, it's not safe, stop the request and clean up everything
            client.stop();
            cleanupWebServer();
            client = NULL;
            Serial.println(F("buffer overrun occurred, POST body may have been too big"));
          }
        } else {
          finishedReadingLine = true;
        }
      }
      else {
        lineLength = client.readBytesUntil('\n', lineBuffer, lineBufferLen);
        finishedReadingLine = true;
      }

      if (finishedReadingLine) {
        // close the buffer off to make it a valid C string
        lineBuffer[lineLength] = 0;
        if (debug) {
          String ll = String("[") + lineLength + String("]:");
          Serial.print(ll);
          DEBUG_OUT(lineBuffer);
        }
        // now interpret the line or, if it's a POST buffer, interpret the buffer
        if (firstLine) {
          output = readRequestLine(lineBuffer);
          firstLine = false;
        }
        else {
          // an http request ends with a blank line
          // wait for an empty line to indicate the end of the header, then wait for post data if required
          if (strlen(lineBuffer) <= 1) {
            gotHeaders = true;
          }
          else if (gotHeaders) {
            // next line is POST data
            if (postFunction) {
              output = postFunction(lineBuffer);
            }
          }
          if (gotHeaders && (output || !postFunction)) {
            // if we have got all the headers and we either
            if (sendFavicon) {
              sendFaviconToClient(client);
            }
            else if (sendWebsite) {
              writeWebsite(client);
            }
            else {
              writeWebServiceReply(client, output);
            }
            // give the web browser time to receive the data
            delay(1);
            // close the connection:
            client.stop();
          }
        }
      }
    }
  } else {
    // we don't yet have a connection from the web client, check if one is available
    client = server.available();
    if (client) {
      if (debug) {
        DEBUG_OUT(F("got a client"));
      }
      // set everything up for a new client
      cleanupWebServer();
    }
  }
}









/*
 *
 *  Static (ish) Website
 *
 */


static const int favIconLength = 635;
static const PROGMEM byte fd[] = {
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x10, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x91, 0x68,
  0x36, 0x00, 0x00, 0x02, 0x42, 0x49, 0x44, 0x41, 0x54, 0x28, 0xcf, 0x6d, 0x92, 0xcf, 0x4f, 0x13,
  0x51, 0x10, 0xc7, 0x67, 0xde, 0x7b, 0xbb, 0x4b, 0x29, 0xed, 0x86, 0x72, 0x90, 0xd8, 0x4a, 0x2d,
  0xa8, 0x34, 0x8a, 0x0a, 0x22, 0x31, 0x92, 0x78, 0x21, 0x31, 0x46, 0x12, 0x7f, 0x10, 0x62, 0xf4,
  0xe0, 0xd1, 0x8b, 0xff, 0x81, 0x57, 0x2f, 0x26, 0x5e, 0xf4, 0xe2, 0xd1, 0x8b, 0x07, 0x35, 0x91,
  0xc4, 0x68, 0xf0, 0x22, 0x37, 0x54, 0x44, 0x94, 0x94, 0x84, 0x08, 0x6a, 0x8c, 0x42, 0x20, 0x56,
  0x5b, 0x59, 0xba, 0xb6, 0x6c, 0xa5, 0xbb, 0xef, 0xbd, 0xf1, 0x50, 0x68, 0x4b, 0xe2, 0x37, 0x73,
  0x9a, 0x99, 0x6f, 0x26, 0x33, 0xf3, 0xc1, 0x4c, 0xd6, 0x85, 0x6d, 0x21, 0x00, 0x21, 0x68, 0xa5,
  0xb5, 0x56, 0x8c, 0x40, 0x03, 0x01, 0xa1, 0x30, 0x4d, 0x00, 0xaa, 0xf5, 0x08, 0x68, 0x10, 0x01,
  0x70, 0xe4, 0xdf, 0xbe, 0x2e, 0x4a, 0x5f, 0x9a, 0xa1, 0x10, 0x00, 0xb9, 0xce, 0xda, 0xde, 0x54,
  0x57, 0x6b, 0x7b, 0x3b, 0x68, 0xfa, 0x8f, 0x01, 0x11, 0x73, 0xbf, 0xb2, 0x65, 0xcf, 0x3b, 0x7c,
  0x6c, 0x80, 0x71, 0x8e, 0x00, 0x52, 0xaa, 0x97, 0xcf, 0x9e, 0x0c, 0x8f, 0x5e, 0xd1, 0xdb, 0x43,
  0x58, 0xa3, 0x41, 0xca, 0x60, 0xe9, 0xf3, 0xa7, 0xf8, 0x9e, 0x24, 0x00, 0x68, 0xa5, 0x94, 0x52,
  0xc8, 0x71, 0xe8, 0xcc, 0xb9, 0xb1, 0x07, 0xf7, 0x43, 0xa1, 0xf0, 0x0e, 0x03, 0x02, 0x20, 0xe3,
  0xb9, 0xd5, 0x95, 0xd2, 0x46, 0x69, 0x57, 0x22, 0x51, 0x9f, 0xa9, 0x29, 0x14, 0x89, 0x74, 0x75,
  0xa7, 0x67, 0xa7, 0x26, 0x39, 0x17, 0x0d, 0x06, 0xc6, 0xbc, 0xa2, 0x3b, 0x31, 0xfe, 0x7c, 0x78,
  0xe4, 0x92, 0x96, 0x9a, 0x0b, 0x51, 0x0d, 0x26, 0x04, 0x02, 0xf4, 0x9e, 0x18, 0x5c, 0x5d, 0xfe,
  0x5e, 0x70, 0xd6, 0x10, 0x11, 0xab, 0x57, 0xe2, 0x8c, 0xdf, 0xb9, 0x79, 0x63, 0xe8, 0xec, 0x05,
  0x3b, 0xd6, 0xea, 0x6f, 0xfa, 0x7f, 0xcb, 0x65, 0x25, 0x7d, 0x22, 0x30, 0xad, 0x26, 0xd3, 0x32,
  0x0d, 0xcb, 0xca, 0x2e, 0x2f, 0x15, 0x8b, 0xee, 0xe9, 0xf3, 0xa3, 0xa2, 0xba, 0xab, 0xe7, 0x6d,
  0xec, 0x4f, 0xf7, 0xcc, 0x4e, 0xbf, 0xca, 0xff, 0xcc, 0x3a, 0xf9, 0xdc, 0xf1, 0xc1, 0x53, 0xbb,
  0x3b, 0x92, 0x0c, 0xd9, 0xe4, 0xc4, 0x8b, 0x8d, 0x3f, 0xc5, 0x88, 0x1d, 0x8d, 0xb6, 0xb6, 0xa5,
  0x0e, 0x74, 0x13, 0x00, 0x66, 0xb2, 0xae, 0xd6, 0x6a, 0xb3, 0xec, 0x85, 0xc3, 0xd1, 0x50, 0x50,
  0xc9, 0xe7, 0x73, 0xf3, 0xd3, 0x6f, 0x07, 0x2f, 0x8e, 0xf0, 0xa6, 0x66, 0x26, 0xf8, 0xe2, 0xdc,
  0x5c, 0xb2, 0x33, 0xd5, 0x62, 0xc7, 0x88, 0x34, 0x29, 0x2d, 0x95, 0x14, 0x08, 0x18, 0x54, 0x82,
  0xa7, 0x8f, 0x1f, 0x8e, 0xf4, 0xf5, 0x27, 0xee, 0xdd, 0x0e, 0x1b, 0xcd, 0x9d, 0xc5, 0x82, 0xf4,
  0x4a, 0xce, 0xb5, 0xeb, 0xcc, 0x0f, 0x12, 0xa9, 0xd4, 0x97, 0x85, 0x8f, 0xbd, 0x03, 0x27, 0xb5,
  0x56, 0x54, 0xfb, 0x43, 0x4b, 0x34, 0x92, 0xec, 0xda, 0x17, 0xb1, 0x6d, 0x9e, 0xcf, 0xdb, 0x9c,
  0xa3, 0xef, 0x17, 0xa4, 0xc4, 0x6a, 0x99, 0x0b, 0xa5, 0x14, 0x60, 0xfd, 0xd5, 0x8c, 0x80, 0xd6,
  0xd7, 0x1d, 0x0a, 0x02, 0x27, 0xd6, 0xe6, 0xdc, 0xba, 0x5b, 0xb1, 0x63, 0x0b, 0x3d, 0xbd, 0xbf,
  0x2f, 0x5f, 0x45, 0xa9, 0x10, 0xf9, 0x8f, 0xd5, 0x95, 0x78, 0x47, 0x07, 0xe9, 0x3a, 0x1a, 0x98,
  0xc9, 0xba, 0x88, 0xc8, 0x19, 0x53, 0x1a, 0x08, 0xc9, 0x30, 0xad, 0xcc, 0xbb, 0xa9, 0x74, 0x3a,
  0x6d, 0x34, 0x85, 0x85, 0xe0, 0x73, 0x33, 0xd3, 0x07, 0x8f, 0x1c, 0x15, 0x86, 0x49, 0xb8, 0x05,
  0x14, 0x03, 0x00, 0x22, 0x92, 0x4a, 0x03, 0x29, 0xd4, 0x5a, 0xfa, 0x95, 0x78, 0x3c, 0x31, 0xf3,
  0xe6, 0xf5, 0x66, 0xd9, 0x73, 0xd7, 0x9d, 0x92, 0x5b, 0x90, 0x9a, 0x08, 0xea, 0xf8, 0xd5, 0x58,
  0xa2, 0xad, 0x8c, 0xd6, 0xed, 0xf1, 0xc4, 0xfc, 0x87, 0xf7, 0xe3, 0x63, 0x8f, 0x18, 0xc0, 0xa1,
  0xbe, 0x7e, 0xd3, 0x30, 0x76, 0xf0, 0xd6, 0x88, 0x77, 0x4d, 0x4a, 0x29, 0xbf, 0x52, 0x41, 0x44,
  0xcb, 0xb2, 0x90, 0xed, 0xe0, 0xed, 0x1f, 0xa5, 0xdd, 0x0f, 0xa7, 0xf2, 0x58, 0x08, 0xb7, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
};

void sendFaviconToClient(EthernetClient client) {
  if (debug) {
    DEBUG_OUT(F("FAVICON"));
  }

  static const int favIconBufferLength = 200;
  byte * faviconInRam = (byte*)malloc(favIconBufferLength);
  if (faviconInRam) {
    int offset = 0;
    for (int i = 0; i <= favIconLength; i++) {
      offset = i % favIconBufferLength;
      if (i && !offset) {
        client.write(faviconInRam, favIconBufferLength);
      }
      faviconInRam[offset] = pgm_read_byte(fd + i);
    }
    if (offset) {
      client.write(faviconInRam, offset);
    }
    free(faviconInRam);
  }
  else {
    DEBUG_OUT(F("failed to get favicon buffer"));
    DEBUG_OUT(errno);
  }
}

void writeWebsiteSection(EthernetClient client, const char * section, const int length) {
  byte * sectionInRam = (byte*)malloc(length);
  if (sectionInRam) {
    for (int i = 0; i <= length; i++) {
      sectionInRam[i] = pgm_read_byte(section + i);
    }
    client.write(sectionInRam, length + 1);
    free(sectionInRam);
  }
  else {
    DEBUG_OUT(F("could not write website section - could not malloc"));
  }
}

const int webHeaderLength = 43;
const PROGMEM char webHeader[] =
  "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n";

const int website1Length = 82;
const PROGMEM char website1[] =
  "<link rel='stylesheet' type='text/css' href='http://10.0.1.102/weather/lights.css'>";

const int website1aLength = 101;
const PROGMEM char website1a[] =
  "<div id='pageTitle'>light control</div><div><p>Tube Lamp : <input type='checkbox' id='lamp2' disabled ";

const int website2Length = 63;
const PROGMEM char website2[] =
  "></p><p>Round Lamp : <input type='checkbox' id='lamp1' disabled ";

const int website3Length = 64;
const PROGMEM char website3[] =
  "></p><p>Corner Lamp : <input type='checkbox' id='lamp3' disabled ";

const int website4Length = 88;
const PROGMEM char website4[] =
  "><p></div><script src='https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js'>";

const int website4aLength = 67;
const PROGMEM char website4a[] =
  "</script><script src='http://10.0.1.102/weather/lights.js'></script>";

void writeWebsite(EthernetClient client) {
  writeWebsiteSection(client, webHeader, webHeaderLength);
  writeWebsiteSection(client, website1, website1Length);
  writeWebsiteSection(client, website1a, website1aLength);
  if (!lightTwoState) {
    client.write((byte*)"checked", 7);
  }
  writeWebsiteSection(client, website2, website2Length);
  if (!lightOneState) {
    client.write((byte*)"checked", 7);
  }
  writeWebsiteSection(client, website3, website3Length);
  if (!lightThreeState) {
    client.write((byte*)"checked", 7);
  }
  writeWebsiteSection(client, website4, website4Length);
  writeWebsiteSection(client, website4a, website4aLength);
}














