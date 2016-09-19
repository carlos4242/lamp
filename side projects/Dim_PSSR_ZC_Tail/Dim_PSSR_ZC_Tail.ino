/*
 Dim_PSSR_ZC_Tail

 This sketch is a sample sketch using the ZeroCross Tail(ZCT) to generate a sync
 pulse to drive a PowerSSR Tail(PSSRT) for dimming ac lights.

 Connections to an Arduino Duemilanove:
 1. Connect the C terminal of the ZeroCross Tail to digital pin 2 with a 10K ohm pull up to Arduino 5V.
 2. Connect the E terminal of the ZeroCross Tail to Arduino Gnd.
 3. Connect the PowerSSR Tail +in terminal to digital pin 4 and the -in terminal to Gnd.
*/

#include <EEPROM.h>
#include <TimerOne.h>
#include <stdlib.h>

#define SLAVE_ADDRESS 0x04
#define saveLastTriggerPointAt 0x31
#define saveLampOnAt 0x32
#define minTriggerPoint 5
#define maxTriggerPoint 120
#define serialBufferSize 10 // the maximum length of the serial input/output

volatile boolean zero_cross = false;// Boolean to store a "switch" to tell us if we have crossed zero
int PZCD1 = 2;                  // PowerSwitch Zero detect on this pin (must be interrupt capable)
int PSSR1 = 4;                  // PowerSSR Tail connected to this digital pin to control power
int triggerPoint = minTriggerPoint;          // Default dimming level (0-128)  0 = on, 128 = off
int freqStep = 60;              // Set to 60hz mains
boolean lampOn = true;

#define EEPROMUpdate(address,value) do {\
    byte current = EEPROM.read(address);\
    if (current != value) {\
      EEPROM.write(address,value);\
    }\
  } while (false);

#define DEBUG_OUT(param) Serial.println(param)

// forward declarations in case we compile this on a pi using make, if using Arduino IDE they're invisibly added
void zero_cross_detect();
void triggerPoint_check();

void setup()
{
  // trigger an interrupt after a zero cross has been detected
  attachInterrupt(digitalPinToInterrupt(PZCD1), zero_cross_detect, RISING);   // Attach an Interupt to the digital pin that reads zero cross pulses

  // fire a timer to count up after zero cross detected until the time when the triac should be fired
  Timer1.initialize(freqStep);
  Timer1.attachInterrupt(triggerPoint_check, freqStep);

  // Set SSR1 pin as output
  pinMode(PSSR1, OUTPUT);

  // read most recent dimming level from EEPROM if available (virgin EEPROM address will read as 0xff)
  //  triggerPoint = EEPROM.read(saveLastTriggerPointAt);
  //  if (triggerPoint > maxTriggerPoint || triggerPoint < minTriggerPoint) {
  //    triggerPoint = maxTriggerPoint;
  //  }

  lampOn = EEPROM.read(saveLampOnAt);

  // serial debugging
  Serial.begin(9600);
  DEBUG_OUT(F(">>Started"));
}

char serialBuffer[serialBufferSize];

void writeStatus() {
  if (lampOn) {
    snprintf(serialBuffer, serialBufferSize, "DMR1=%3d\r\n");
  } else {
    snprintf(serialBuffer, serialBufferSize, "DMR1=_\r\n");
  }
  Serial.write(serialBuffer);
}

void turnOff() {
  lampOn = false;
  EEPROMUpdate(saveLampOnAt, lampOn);
}

void turnOn() {
  lampOn = true;
  EEPROMUpdate(saveLampOnAt, lampOn);
}

void loop()
{ // test with DMR1:?
  // check if serial debugging commands are available
  if (Serial.available()) {
    Serial.readBytesUntil('\r', serialBuffer, serialBufferSize);
    serialBuffer[serialBufferSize] = 0; // ensure null termination
    if (strncmp(serialBuffer, "DMR1:", 5) == 0) {
      //      DEBUG_OUT(F("COMMAND"));
      char * command = serialBuffer + 5;
      if (*command == '?') {
        writeStatus();
      } else if (*command == '_') {
        turnOff();
      } else if (*command == 'O') {
        turnOn();
      } else {
        turnOn();
        int newTriggerPoint = atoi(command);
        if (newTriggerPoint > maxTriggerPoint) {
          newTriggerPoint = maxTriggerPoint;
        } else if (newTriggerPoint < minTriggerPoint) {
          newTriggerPoint = minTriggerPoint;
        }
        triggerPoint = newTriggerPoint;
        EEPROMUpdate(saveLastTriggerPointAt, triggerPoint);
      }
      //      DEBUG_OUT(triggerPoint);
      //      DEBUG_OUT(lampOn);

    } else {
      //      DEBUG_OUT(F("NOT A COMMAND"));
    }
  }
}

// This function will fire the triac at the proper time
void triggerPoint_check() {
  // First check to make sure the zero-cross has happened and the light should be on else do nothing
  if (zero_cross && lampOn) {
    //    DEBUG_OUT(F("zero cross"));
    static int i = 0; // count the number of interrupts fired by the timer since the last zero cross
    if (i >= triggerPoint) {
      //      DEBUG_OUT(F("trigger"));
      delayMicroseconds(100);        //These values will fire the PSSR Tail.
      digitalWrite(PSSR1, HIGH);
      delayMicroseconds(50);
      digitalWrite(PSSR1, LOW);
      i = 0;                         // Reset the counter
      zero_cross = false;            // Reset the zero_cross so it may be turned on again at the next zero_cross_detect
    } else {
      i++;                           // If the trigger point has not been reached, increment the counter
    }
  }
}

void zero_cross_detect()
{
  zero_cross = true;
}

// recently replaced code from the loop...
//  String s = Serial.readString();
//  if (s.length()) {
//    DEBUG_OUT(F("input:"));
//    DEBUG_OUT(s);
//    if (s == "?") {
//      DEBUG_OUT(F("dim:"));
//      DEBUG_OUT(dim);
//    } else {
//      int newDim = s.toInt();
//      if (newDim > maxBrightness) {
//        newDim = maxBrightness;
//      } else if (newDim < minBrightness) {
//        newDim = minBrightness;
//      }
//      dim = maxBrightness - newDim;
//      DEBUG_OUT(F("newDim:"));
//      DEBUG_OUT(dim);
//      EEPROMUpdate(saveLastTriggerPointAt, dim);
//    }
//  }


// ...old code, control via the I2C interface
//#include <Wire.h>
//#include <SPI.h>

// old setup code
// i2C
//  Wire.begin(SLAVE_ADDRESS);
//  Wire.onReceive(receiveWireData);
//  Wire.onRequest(sendWireData);


//void receiveWireData(int byteCount){
// while(Wire.available()) {
//  int incomingByte = Wire.read();
//if (incomingByte > maxBrightness) {
//  incomingByte = maxBrightness;
//} else if (incomingByte < minBrightness) {
//  incomingByte = minBrightness;
//}
//
//  dim = maxBrightness - incomingByte;
//  EEPROMUpdate(saveLastDim,dim);
// }
//}
//
//void sendWireData(){
//  Wire.write(maxBrightness - dim);
//}
