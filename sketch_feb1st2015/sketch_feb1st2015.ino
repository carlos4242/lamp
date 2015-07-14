#include <SPI.h>
#include <Ethernet.h>
#include <avr/wdt.h>
#include <avr/pgmspace.h>
#include <EEPROM.h>

// Initialize the Ethernet server library
// with the IP address and port you want to use 
// (port 80 is default for HTTP):
EthernetServer server(80);

int lightOne =  7;
int lightTwo = 6;
int lightThree = 5;
int overrideSwitch = 2;

// state flags :
int lightOneState;
int lightTwoState;
int lightThreeState;
boolean debug = true;

void setup()   {
  // setup pins :
  pinMode(lightOne, OUTPUT);
  pinMode(lightTwo, OUTPUT);
  pinMode(lightThree, OUTPUT);
  pinMode(overrideSwitch, INPUT);

  // setup serial :
  Serial.begin(9600);

  // assign a MAC and IP addresses for the ethernet controller :
  byte mac[] = {
    0x90,0xA2,0xDA,0x0D,0x9C,0x31            };
  IPAddress ip(10,0,1,160);
  Ethernet.begin(mac, ip);

  // start the ethernet server :
  server.begin();

  // restore light state from eeprom :
  allOff();
  lightOneState = EEPROM.read(lightOne);
  lightTwoState = EEPROM.read(lightTwo);
  lightThreeState = EEPROM.read(lightThree);
  setLines();

  // start the watchdog timer :
  wdt_enable(WDTO_8S); // have the wdt reset the chip
}

const int statusBufferLen = 50;
char statusBuffer[statusBufferLen];

// helper function to get status :
char * statusString() {
  strncpy(statusBuffer,"{\"lamp1\":X,\"lamp2\":X,\"lamp3\":X}",statusBufferLen);
  statusBuffer[9] = 48+lightOneState; // 
  statusBuffer[19] = 48+lightTwoState;
  statusBuffer[29] = 48+lightThreeState;
  return statusBuffer;
}

// report status on serial port
void report() {
  Serial.println(statusString());
}

void setLines() {
  digitalWrite(lightOne, lightOneState);
  digitalWrite(lightTwo, lightTwoState);
  digitalWrite(lightThree, lightThreeState);

  EEPROM.write(lightOne, lightOneState);
  EEPROM.write(lightTwo, lightTwoState);
  EEPROM.write(lightThree, lightThreeState);
}

// helper function, set all on :
void allOn() {
  lightOneState = LOW;
  lightTwoState = LOW;
  lightThreeState = LOW;
}

// helper function, set all off :
void allOff() {
  lightOneState = HIGH;
  lightTwoState = HIGH;
  lightThreeState = HIGH;
}

void loop()                     
{
  if (Serial.available() > 0) {
    // read the incoming byte:
    int incomingByte = Serial.read();
    if(incomingByte == 97){ // a
      lightOneState = HIGH;
      setLines();
      report(); 
    }
    else if(incomingByte == 98){ // b
      lightOneState = LOW;
      setLines();
      report(); 
    }
    else if(incomingByte == 99){ // c
      lightTwoState = HIGH;
      setLines();
      report(); 
    }
    else if(incomingByte == 100){ // d
      lightTwoState = LOW;
      setLines();
      report(); 
    }
    else if(incomingByte == 101){ // e
      lightThreeState = HIGH;
      setLines();
      report(); 
    }
    else if(incomingByte == 102){ // f
      lightThreeState = LOW;
      setLines();
      report(); 
    }
    else if(incomingByte == 48){ // 0
      allOff();
      setLines();
      report(); 
    }
    else if(incomingByte == 49){ // 1
      allOn();
      setLines();
      report(); 
    }
    else if(incomingByte == 115){ // s
      report();
    }
    else if(incomingByte == 68){ // D - debug toggle
      debug = !debug;
      if (debug) {
        Serial.println("http debug on");
      } 
      else {
        Serial.println("http debug off");
      } 
    }
  }

  int override = digitalRead(overrideSwitch);
  if (override == HIGH) {
    Serial.println("high");
    if (lightOneState == HIGH && lightTwoState == HIGH && lightThreeState == HIGH) {
      allOn();
    } 
    else {
      allOff();
    }
    setLines();
    report();
    while (override == HIGH) {
      delay(1);
      override = digitalRead(overrideSwitch);
    }
    delay(1);
  }

  listenForEthernetClients();
  wdt_reset(); // reset the wdt
}

char * getLightsString = "GET /lights";
char * getLightString = "GET /lights/";
char * getFavicon = "GET /favicon";
char * getWebsite = "GET /";
char * light1 = "light1";
char * light2 = "light2";
char * light3 = "light3";
char * textContentType = "Content-Type: text/plain";
char * htmlContentType = "Content-Type: text/html";


// webserver new API endpoints
// GET /   ... get web code
// GET /lights   ... get json of lights status
// GET /lights/light1   ...   get json of single light status

String getRequest;
const int lineBufferLen = 200;
char lineBuffer[lineBufferLen];
char light[lineBufferLen];
char postData[lineBufferLen];

char * getLightStatus(char * light) {
  int lightStatus;
  if (strncmp(light,light1,strlen(light1)) == 0) {
    lightStatus = lightOneState;
  } 
  else if (strncmp(light,light2,strlen(light2)) == 0) {
    lightStatus = lightTwoState;
  } 
  else if (strncmp(light,light3,strlen(light3)) == 0) {
    lightStatus = lightThreeState;
  } 
  else {
    return "invalid";
  }
  Serial.println("get light status for...");
  Serial.println(light);
  String s1 = String(lightStatus);
  Serial.println(s1);
  char * buffer = statusBuffer;

  strncpy(buffer,"{\"",2);
  buffer += 2;
  strncpy(buffer,light,strlen(light1));
  buffer += strlen(light1);
  strncpy(buffer,"\":X}",5);
  buffer[2] = 48+lightStatus;
  return statusBuffer;
}
char * getLightsStatus() {
  return statusString();
}

// POST /lights  ...  allOn=1 ... turn all lights on and return json of lights status
// POST /lights  ...  allOff=1 ... turn all lights off and return json of lights status
// POST /lights/light2  ...  on=x  ... turn lights on or off (1 and 0 are only recognized values) returns json of single light status

char * postLightsString = "POST /lights";
char * postLightString = "POST /lights/";
char * onSwitchParam = "on=";
char * allOnParam = "allOn=1";
char * allOffParam = "allOff=1";

char * changeLightStatus() {
  // use light to define which light is affected and postData to define how it's affected
  int lightSwitchValue;
  if (strncmp(postData,onSwitchParam,strlen(onSwitchParam)) == 0) {
    char * lightSwitchValueString = postData + strlen(onSwitchParam);
    lightSwitchValue = atoi(lightSwitchValueString);
  } 
  else {
    return "invalid";
  }
  if (strncmp(light,light1,strlen(light1)) == 0) {
    lightOneState = lightSwitchValue;
    setLines();
    return getLightStatus(light);
  }
  else if (strncmp(light,light2,strlen(light2)) == 0) {
    lightTwoState = lightSwitchValue;
    setLines();
    return getLightStatus(light);
  }
  else if (strncmp(light,light3,strlen(light3)) == 0) {
    lightThreeState = lightSwitchValue;
    setLines();
    return getLightStatus(light);
  }
  else {
    return "invalid";
  }
}
char * changeLightsStatus() {
  // use postData to define command
  if (strncmp(postData,allOnParam,strlen(allOnParam)) == 0) {
    allOn();
    setLines();
    return getLightsStatus();
  } 
  else if (strncmp(postData,allOffParam,strlen(allOffParam)) == 0) {
    allOff();
    setLines();
    return getLightsStatus();
  } 
  else {
    return "invalid";
  }
}

boolean sendFavicon;
boolean sendWebsite;
char * (*postFunction)();

char * readFirstLine() {
  if (strncmp(lineBuffer,getLightString,strlen(getLightString)) == 0) {
    if (debug) {
      Serial.println("get light");
    }
    // get the status of a single light
    return getLightStatus(lineBuffer+strlen(getLightString));
  } 
  else if (strncmp(lineBuffer,getLightsString,strlen(getLightsString)) == 0) {
    if (debug) {
      Serial.println("get lights");
    }
    // get the status of all lights
    return getLightsStatus();
  } 
  else if (strncmp(lineBuffer,getFavicon,strlen(getFavicon)) == 0) {
    if (debug) {
      Serial.println("favicon");
    }
    // send the favicon
    sendFavicon = true;
    return 0;
  }
  else if (strncmp(lineBuffer,postLightString,strlen(postLightString)) == 0) {
    if (debug) {
      Serial.println("post light");
    }
    // set the status of a light
    strncpy(light,lineBuffer+strlen(postLightString),lineBufferLen);
    postFunction = changeLightStatus;
    return 0;
  }
  else if (strncmp(lineBuffer,postLightsString,strlen(postLightsString)) == 0) {
    if (debug) {
      Serial.println("post lights");
    }
    // set the status of a light
    strncpy(light,"",1);
    postFunction = changeLightsStatus;
    return 0;
  } 
  else if (strncmp(lineBuffer,getWebsite,strlen(getWebsite)) == 0) {
    if (debug) {
      Serial.println("get website");
    }
    // send the website
    sendWebsite = true;
    return 0;
  }
  else {
    if (debug) {
      // this is a dodgy http request
      Serial.println("Invalid http request");
      Serial.println(lineBuffer);
    }
    return 0;
  }
}

const PROGMEM byte fd[] = {
  0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,0x00,0x00,0x00,0x0d,0x49,0x48,0x44,0x52,
  0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x10,0x08,0x02,0x00,0x00,0x00,0x90,0x91,0x68,
  0x36,0x00,0x00,0x02,0x42,0x49,0x44,0x41,0x54,0x28,0xcf,0x6d,0x92,0xcf,0x4f,0x13,
  0x51,0x10,0xc7,0x67,0xde,0x7b,0xbb,0x4b,0x29,0xed,0x86,0x72,0x90,0xd8,0x4a,0x2d,
  0xa8,0x34,0x8a,0x0a,0x22,0x31,0x92,0x78,0x21,0x31,0x46,0x12,0x7f,0x10,0x62,0xf4,
  0xe0,0xd1,0x8b,0xff,0x81,0x57,0x2f,0x26,0x5e,0xf4,0xe2,0xd1,0x8b,0x07,0x35,0x91,
  0xc4,0x68,0xf0,0x22,0x37,0x54,0x44,0x94,0x94,0x84,0x08,0x6a,0x8c,0x42,0x20,0x56,
  0x5b,0x59,0xba,0xb6,0x6c,0xa5,0xbb,0xef,0xbd,0xf1,0x50,0x68,0x4b,0xe2,0x37,0x73,
  0x9a,0x99,0x6f,0x26,0x33,0xf3,0xc1,0x4c,0xd6,0x85,0x6d,0x21,0x00,0x21,0x68,0xa5,
  0xb5,0x56,0x8c,0x40,0x03,0x01,0xa1,0x30,0x4d,0x00,0xaa,0xf5,0x08,0x68,0x10,0x01,
  0x70,0xe4,0xdf,0xbe,0x2e,0x4a,0x5f,0x9a,0xa1,0x10,0x00,0xb9,0xce,0xda,0xde,0x54,
  0x57,0x6b,0x7b,0x3b,0x68,0xfa,0x8f,0x01,0x11,0x73,0xbf,0xb2,0x65,0xcf,0x3b,0x7c,
  0x6c,0x80,0x71,0x8e,0x00,0x52,0xaa,0x97,0xcf,0x9e,0x0c,0x8f,0x5e,0xd1,0xdb,0x43,
  0x58,0xa3,0x41,0xca,0x60,0xe9,0xf3,0xa7,0xf8,0x9e,0x24,0x00,0x68,0xa5,0x94,0x52,
  0xc8,0x71,0xe8,0xcc,0xb9,0xb1,0x07,0xf7,0x43,0xa1,0xf0,0x0e,0x03,0x02,0x20,0xe3,
  0xb9,0xd5,0x95,0xd2,0x46,0x69,0x57,0x22,0x51,0x9f,0xa9,0x29,0x14,0x89,0x74,0x75,
  0xa7,0x67,0xa7,0x26,0x39,0x17,0x0d,0x06,0xc6,0xbc,0xa2,0x3b,0x31,0xfe,0x7c,0x78,
  0xe4,0x92,0x96,0x9a,0x0b,0x51,0x0d,0x26,0x04,0x02,0xf4,0x9e,0x18,0x5c,0x5d,0xfe,
  0x5e,0x70,0xd6,0x10,0x11,0xab,0x57,0xe2,0x8c,0xdf,0xb9,0x79,0x63,0xe8,0xec,0x05,
  0x3b,0xd6,0xea,0x6f,0xfa,0x7f,0xcb,0x65,0x25,0x7d,0x22,0x30,0xad,0x26,0xd3,0x32,
  0x0d,0xcb,0xca,0x2e,0x2f,0x15,0x8b,0xee,0xe9,0xf3,0xa3,0xa2,0xba,0xab,0xe7,0x6d,
  0xec,0x4f,0xf7,0xcc,0x4e,0xbf,0xca,0xff,0xcc,0x3a,0xf9,0xdc,0xf1,0xc1,0x53,0xbb,
  0x3b,0x92,0x0c,0xd9,0xe4,0xc4,0x8b,0x8d,0x3f,0xc5,0x88,0x1d,0x8d,0xb6,0xb6,0xa5,
  0x0e,0x74,0x13,0x00,0x66,0xb2,0xae,0xd6,0x6a,0xb3,0xec,0x85,0xc3,0xd1,0x50,0x50,
  0xc9,0xe7,0x73,0xf3,0xd3,0x6f,0x07,0x2f,0x8e,0xf0,0xa6,0x66,0x26,0xf8,0xe2,0xdc,
  0x5c,0xb2,0x33,0xd5,0x62,0xc7,0x88,0x34,0x29,0x2d,0x95,0x14,0x08,0x18,0x54,0x82,
  0xa7,0x8f,0x1f,0x8e,0xf4,0xf5,0x27,0xee,0xdd,0x0e,0x1b,0xcd,0x9d,0xc5,0x82,0xf4,
  0x4a,0xce,0xb5,0xeb,0xcc,0x0f,0x12,0xa9,0xd4,0x97,0x85,0x8f,0xbd,0x03,0x27,0xb5,
  0x56,0x54,0xfb,0x43,0x4b,0x34,0x92,0xec,0xda,0x17,0xb1,0x6d,0x9e,0xcf,0xdb,0x9c,
  0xa3,0xef,0x17,0xa4,0xc4,0x6a,0x99,0x0b,0xa5,0x14,0x60,0xfd,0xd5,0x8c,0x80,0xd6,
  0xd7,0x1d,0x0a,0x02,0x27,0xd6,0xe6,0xdc,0xba,0x5b,0xb1,0x63,0x0b,0x3d,0xbd,0xbf,
  0x2f,0x5f,0x45,0xa9,0x10,0xf9,0x8f,0xd5,0x95,0x78,0x47,0x07,0xe9,0x3a,0x1a,0x98,
  0xc9,0xba,0x88,0xc8,0x19,0x53,0x1a,0x08,0xc9,0x30,0xad,0xcc,0xbb,0xa9,0x74,0x3a,
  0x6d,0x34,0x85,0x85,0xe0,0x73,0x33,0xd3,0x07,0x8f,0x1c,0x15,0x86,0x49,0xb8,0x05,
  0x14,0x03,0x00,0x22,0x92,0x4a,0x03,0x29,0xd4,0x5a,0xfa,0x95,0x78,0x3c,0x31,0xf3,
  0xe6,0xf5,0x66,0xd9,0x73,0xd7,0x9d,0x92,0x5b,0x90,0x9a,0x08,0xea,0xf8,0xd5,0x58,
  0xa2,0xad,0x8c,0xd6,0xed,0xf1,0xc4,0xfc,0x87,0xf7,0xe3,0x63,0x8f,0x18,0xc0,0xa1,
  0xbe,0x7e,0xd3,0x30,0x76,0xf0,0xd6,0x88,0x77,0x4d,0x4a,0x29,0xbf,0x52,0x41,0x44,
  0xcb,0xb2,0x90,0xed,0xe0,0xed,0x1f,0xa5,0xdd,0x0f,0xa7,0xf2,0x58,0x08,0xb7,0x00,
  0x00,0x00,0x00,0x49,0x45,0x4e,0x44,0xae,0x42,0x60,0x82};

const PROGMEM char website[] =
"<h1>light control</h1>\n"
"<script></script>\n"
"place holder website"
;

void listenForEthernetClients() {
  EthernetClient client = server.available();
  if (client) {
    if (debug) {
      Serial.println("Got a client");
    }
    sendFavicon = false;
    sendWebsite = false;
    postFunction = 0;
    boolean firstLine = true;
    boolean gotHeaders = false;
    char * output = 0;
    // an http request ends with a blank line
    while (client.connected()) {
      if (client.available()) {
        int lineLength = client.readBytesUntil('\n',lineBuffer,lineBufferLen);
        lineBuffer[lineLength] = 0;
        if (debug) {
          String ll = String("[") + lineLength + String("]:");
          Serial.print(ll);
          Serial.println(lineBuffer);
        }
        if (firstLine) {
          output = readFirstLine();
          firstLine = false;
        } 
        else {
          // wait for an empty line to indicate the end of the header, then wait for post data if required
          if (strlen(lineBuffer) <= 1) {
            gotHeaders = true;
            if (debug) {
              Serial.println("got headers");
            }
          } 
          else if (gotHeaders) {
            // next line is POST data
            if (postFunction) {
              strncpy(postData,lineBuffer,lineBufferLen);
              output = postFunction();
              if (debug) {
                Serial.println("performed post function");
              }
            }
          }
          if (gotHeaders && (postData || !postFunction)) {
            if (sendFavicon) {
              if (debug) {
                Serial.println("FAVICON");
              }
              for (int i = 0; i < 635; i++) {
                byte b = pgm_read_byte(fd+i);
                client.write(b);
              }
            } 
            else {
              // got headers and either have post data or it's not a post request, so send back headers
              client.println("HTTP/1.0 200 OK");
              if (sendWebsite) {
                client.println(htmlContentType);
              } 
              else {
                client.println(textContentType);
              }
              client.println();
              if (sendWebsite) {
                for (int i = 0; i < strlen(website); i++) {
                  byte b = pgm_read_byte(website+i);
                  client.write(b);
                }
              } 
              else {
                client.println(output);
              }
            }
            if (debug) {
              Serial.println("client finished, waiting");
            }
            // give the web browser time to receive the data
            delay(1);
            // close the connection:
            client.stop();
            if (debug) {
              Serial.println("client disconnected at server");
            }
          }
        }
      }
    }
  }
}




