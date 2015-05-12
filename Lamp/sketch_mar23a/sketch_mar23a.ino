//

#include <SPI.h>
#include <Ethernet.h>
#include <avr/wdt.h>

int lightOne =  7;    // relay connected to digital pin 7
int lightTwo = 6;

// change 1
int overrideSwitch = 5;
int pilotLight = 4;

int inverseLightThree = 3;

int beedoBeedo = 2;

int incomingByte = 0;	// for incoming serial data

int lightOneState = LOW;
int lightTwoState = LOW;
int inverseLightThreeState = HIGH;
int beedoBeedoState = LOW;

// The setup() method runs once, when the sketch starts

// assign a MAC address for the ethernet controller.
// fill in your address here:
byte mac[] = {0x90,0xA2,0xDA,0x0D,0x9C,0x31};
// assign an IP address for the controller:
IPAddress ip(10,0,1,160);//10.0.1.1
IPAddress gateway(10,0,1,2);
IPAddress subnet(255, 255, 255, 0);

// Initialize the Ethernet server library
// with the IP address and port you want to use 
// (port 80 is default for HTTP):
EthernetServer server(80);

String getRequest;
char lineBuffer[100];

void setup()   {
  pinMode(lightOne, OUTPUT);
  pinMode(lightTwo, OUTPUT);
  pinMode(overrideSwitch, INPUT);
  pinMode(pilotLight, OUTPUT);
  pinMode(inverseLightThree, OUTPUT);
  pinMode(beedoBeedo, OUTPUT);
  Serial.begin(9600);
  Ethernet.begin(mac, ip);
  server.begin();
  digitalWrite(pilotLight, LOW);
  digitalWrite(inverseLightThree, HIGH);
  digitalWrite(beedoBeedo, LOW);
  
  wdt_enable(WDTO_8S); // have the wdt reset the chip
}

String statusString() {
      String l1p = String("{\"result\":1,\"lamp1\":"); 
      String l1S = String();
      l1S = l1p + lightOneState;
      
      String l2p = String(",\"lamp2\":");
      String l2S = String();
      l2S = l2p + lightTwoState;
      
      String l3p = String(",\"lamp3\":");
      String l3S = String();
      l3S = l3p + inverseLightThreeState;
      
      String l2t = String("}");
      
      String stat = String();
      stat = l1S + l2S + l3S + l2t;
      return stat;
}

void report() {
  String reportString = statusString();
  Serial.println(reportString);
  if (lightOneState == LOW && lightTwoState == LOW && inverseLightThreeState == LOW) {
    digitalWrite(pilotLight, HIGH);
  } else {
    digitalWrite(pilotLight, LOW);
  }
}

void loop()                     
{
  if (Serial.available() > 0) {
    // read the incoming byte:
    incomingByte = Serial.read();
    if(incomingByte == 97){ // a
      digitalWrite(lightOne, HIGH);
      lightOneState = HIGH;
     report(); 
    }
    else if(incomingByte == 98){ // b
      digitalWrite(lightOne, LOW);
      lightOneState = LOW;
     report(); 
    }
    else if(incomingByte == 99){ // c
      digitalWrite(lightTwo, HIGH);
      lightTwoState = HIGH;
     report(); 
    }
    else if(incomingByte == 100){ // d
      digitalWrite(lightTwo, LOW);
      lightTwoState = LOW;
     report(); 
    }
    else if(incomingByte == 101){ // e
      digitalWrite(inverseLightThree, HIGH);
      inverseLightThreeState = HIGH;
     report(); 
    }
    else if(incomingByte == 102){ // f
      digitalWrite(inverseLightThree, LOW);
      inverseLightThreeState = LOW;
     report(); 
    }
    else if(incomingByte == 115){ // s
     report(); 
    }
  }
  
  int override = digitalRead(overrideSwitch);
  if (override == HIGH) {
    if (lightOneState == LOW) {
      digitalWrite(lightOne, HIGH);
      digitalWrite(lightTwo, HIGH);
      digitalWrite(inverseLightThree, LOW);
      lightOneState = HIGH;
      lightTwoState = HIGH;
      inverseLightThreeState = LOW;
    } else {
      digitalWrite(lightOne, LOW);
      digitalWrite(lightTwo, LOW);
      digitalWrite(inverseLightThree, HIGH);
      lightOneState = LOW;
      lightTwoState = LOW;
      inverseLightThreeState = HIGH;
    }
    report();
    while (override == HIGH) {
      delay(1);
      override = digitalRead(overrideSwitch);
    }
  }
  
  listenForEthernetClients();
  wdt_reset(); // reset the wdt
}


// webserver endpoints
// / shows status
// /a turns lamp 1 on
// /b turns lamp 1 off
// /c turns lamp 2 on
// /d turns lamp 2 off
// each on/off command also returns status
// status returns according to the format
// "{\"result\":1,\"lamp1\":".$lamp1Status.",\"lamp2\":".$lamp2Status."}\r\n"

void listenForEthernetClients() {
  EthernetClient client = server.available();
  if (client) {
    Serial.println("Got a client");
    int iPos = 0;
    boolean gotGetRequest = false;
    // an http request ends with a blank line
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        lineBuffer[iPos] = c;
        iPos++;
        if (c == '\n') {
          lineBuffer[iPos] = 0;
          if (!gotGetRequest) {
            if (iPos<6) {
              Serial.println("Invalid get request");
            } else {
              getRequest = String(lineBuffer+5);
              Serial.print(getRequest);
              gotGetRequest = true;
            } 
          }
          if (iPos<3) {
            if (gotGetRequest) {
              char request = getRequest[0];
              if (request == 'a') {
                // turn on L1
                digitalWrite(lightOne, HIGH);
                lightOneState = HIGH;
              }
              else if (request == 'b') {
                // turn off L1
                digitalWrite(lightOne, LOW);
                lightOneState = LOW;
              }
              else if (request == 'c') {
                // turn on L2
                digitalWrite(lightTwo, HIGH);
                lightTwoState = HIGH;
              }
              else if (request == 'd') {
                // turn off L2
                digitalWrite(lightTwo, LOW);
                lightTwoState = LOW;
              }
              else if (request == 'e') {
                // turn on L3
                digitalWrite(inverseLightThree, HIGH);
                inverseLightThreeState = HIGH;
              }
              else if (request == 'f') {
                // turn off L3
                digitalWrite(inverseLightThree, LOW);
                inverseLightThreeState = LOW;
              }
            }
            // send a standard http response header
            client.println("HTTP/1.1 200 OK");
            client.println("Content-Type: text/html");
            client.println();
            String stat = statusString();
            client.println(stat);
            break;
          }
          iPos = 0;
        } // if c == '\n'
      } // if client.available
    } // while client.connected
    // give the web browser time to receive the data
    delay(1);
    // close the connection:
    client.stop();
    report();
  }
}
