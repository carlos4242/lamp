#include <Wire.h>
#include <avr/wdt.h>
#include <avr/pgmspace.h>
#include <EEPROM.h>
#include "errno.h"
//#include <utility/w5100.h>
#include <ADCTouch.h>
// sourced from https://github.com/Megunolink/ArduinoCrashMonitor
// referenced by http://www.megunolink.com/how-to-detect-lockups-using-the-arduino-watchdog/
#include <ApplicationMonitor.h>
 
#define SLAVE_ADDRESS 0x04

#define enable_serial_debug 1

#ifdef enable_serial_debug
#include <SPI.h>
#define DEBUG_OUT(param) Serial.println(param)
#define HTTP_DEBUG_OUT(param) {if (debug) {Serial.println(param);}}
#else
#define DEBUG_OUT(param)
#define HTTP_DEBUG_OUT(param)
#endif

#define EEPROMUpdate(address,value) do {\
  byte current = EEPROM.read(address);\
  if (current != value) {\
    EEPROM.write(address,value);\
  }\
} while (false);

#define lightOne 13
#define lightTwo 12
#define lightThree 11

#define sensorOff A0
#define sensorCorner A1
#define sensorOn A2

/*
 * 
 * FORWARD DECLARATIONS
 * 
 */
void setLines();
void readSerialCommands();
void checkTouchSensor();
void allOn();
void allOff();
void cornerOnly();
char * statusString();
double GetTemp();
void receiveWireData(int byteCount);
void sendWireData();

/*
 *
 *  GLOBAL STATE AREA
 *
 */

// Watchdog dump class
Watchdog::CApplicationMonitor ApplicationMonitor;

// touch sensor
int ref0, ref1, ref2;       //reference values to remove offset

// state flags :
boolean lightOneState;
boolean lightTwoState;
boolean lightThreeState;
boolean debug = false;
double temp;




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

  // setup touch sensor
  // This is from here : http://playground.arduino.cc/Code/ADCTouch
  ref0 = ADCTouch.read(sensorOff, 500);    //create reference values to
  ref1 = ADCTouch.read(sensorCorner, 500);      //account for the capacitance of the pad
  ref2 = ADCTouch.read(sensorOn, 500);      //account for the capacitance of the pad

  // setup serial :
  Serial.begin(9600);

   // initialize i2c as slave
 Wire.begin(SLAVE_ADDRESS);
 
 // define callbacks for i2c communication
 Wire.onReceive(receiveWireData);
 Wire.onRequest(sendWireData);

  // restore light state from eeprom :
  lightOneState = EEPROM.read(lightOne);
  lightTwoState = EEPROM.read(lightTwo);
  lightThreeState = EEPROM.read(lightThree);
  setLines();

  // start the watchdog timer :
  ApplicationMonitor.Dump(Serial);
  ApplicationMonitor.EnableWatchdog(Watchdog::CApplicationMonitor::Timeout_4s);

  DEBUG_OUT(F(">>Started"));
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
  delay(100);
  temp = GetTemp();
  ApplicationMonitor.IAmAlive();
}



/*
 *
 *  TOUCH SENSOR
 *
 */

void checkTouchSensor() {
  int offVal = ADCTouch.read(sensorOff);
  int cornerVal = ADCTouch.read(sensorCorner);
  int onVal = ADCTouch.read(sensorOn);

  //no second parameter --> 100 samples
  int value0 = offVal - ref0;
  int value1 = cornerVal - ref1;
  int value2 = onVal - ref2;

  if (value0 > 40) {
    //corner
    DEBUG_OUT("touch - turn off all lamps");
    allOff();
    setLines();
  } else if (value1 > 40) {
    DEBUG_OUT("touch - turn on corner lamp");
    cornerOnly();
    setLines();
  } else if (value2 > 40) {
    DEBUG_OUT("touch - turn on all lamps");
    allOn();
    setLines();
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
    else if (incomingByte == 82) { // R
      ApplicationMonitor.ResetLogData();
      Serial.println(F("Application Monitor log data reset"));
    }
  }
}

char * statusString() {
  static const int statusBufferLen = 20;
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

  EEPROMUpdate(lightOne, lightOneState);
  EEPROMUpdate(lightTwo, lightTwoState);
  EEPROMUpdate(lightThree, lightThreeState);
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


 
// callback for received data
void receiveWireData(int byteCount){
 while(Wire.available()) {
  int incomingByte = Wire.read();
  DEBUG_OUT(F("received i2c data"));
  DEBUG_OUT(incomingByte);
    if (incomingByte == 97) { // a
      lightOneState = HIGH;
      setLines();
    }
    else if (incomingByte == 98) { // b
      lightOneState = LOW;
      setLines();
    }
    else if (incomingByte == 99) { // c
      lightTwoState = HIGH;
      setLines();
    }
    else if (incomingByte == 100) { // d
      lightTwoState = LOW;
      setLines();
    }
    else if (incomingByte == 101) { // e
      lightThreeState = HIGH;
      setLines();
    }
    else if (incomingByte == 102) { // f
      lightThreeState = LOW;
      setLines();
    }
    else if (incomingByte == 48) { // 0
      allOff();
      setLines();
    }
    else if (incomingByte == 49) { // 1
      allOn();
      setLines();
    }
 }
}
 
// callback for sending data
void sendWireData(){
 Wire.write((int)temp);
}
 
// Get the internal temperature of the arduino
double GetTemp()
{
 unsigned int wADC;
 double t;
 ADMUX = (_BV(REFS1) | _BV(REFS0) | _BV(MUX3));
 ADCSRA |= _BV(ADEN); // enable the ADC
 delay(20); // wait for voltages to become stable.
 ADCSRA |= _BV(ADSC); // Start the ADC
 while (bit_is_set(ADCSRA,ADSC));
 wADC = ADCW;
 t = (wADC - 324.31 ) / 1.22;
 return (t);
}

