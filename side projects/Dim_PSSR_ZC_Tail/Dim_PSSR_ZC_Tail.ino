/*
  Dim_PSSR_ZC_Tail

  This sketch is a sample sketch using the ZeroCross Tail(ZCT) to generate a sync
  pulse to drive a PowerSSR Tail(PSSRT) for dimming ac lights.

  Connections to an Arduino Duemilanove:
  1. Connect the C terminal of the ZeroCross Tail to digital pin 2 with a 10K ohm pull up to Arduino 5V.
  2. Connect the E terminal of the ZeroCross Tail to Arduino Gnd.
  3. Connect the PowerSSR Tail +in terminal to digital pin 4 and the -in terminal to Gnd.
   http://bildr.org/2012/08/rotary-encoder-arduino/

  debugging...
  store a log of all that went into the serial port, plus markers '/'
  compilation reports approx 1,713 bytes for local variables plus heap/malloc
  make the serial buffer 500 bytes. log as a ring buffer

  debugging pins...
  11 - dump debug ring buffer and reset (includes >>> after the last bytes to indicate the end
  13 - recognising serial command

*/

#include <EEPROM.h>
#include <TimerOne.h>
#include <stdlib.h>
#include <SoftwareSerial.h>
#include "RingBuffer.h"

// constants
#define RING_BUFFER_SIZE 500
#define saveLastTriggerPointAt 0x31
#define saveLampOnAt 0x32
#define minTriggerPoint 5
#define maxTriggerPoint 90
#define brightnessStep 1
#define brightnessMultiplier 10
#define serialBufferSize 9 // the maximum length of the serial input/output
#define freqStep 10 // Set to 50hz mains

// pins
#define PZCD1 2 // PowerSwitch Zero detect on this pin (must be interrupt capable)
#define encoderSwitchPin 3 // rotary encoder push switch
#define PSSR1 4 // PowerSSR Tail connected to this digital pin to control power
#define encoderPin1 7 // rotary encoder pin1
#define encoderPin2 8 // rotary encoder pin2
#define dbgrxpin 9
#define dbgtxpin 10
#define dumpRingBufferPin 11
#define dbgInRecognizePin 13

// faerie lights
#define faerieLights1 5
#define faerieLights2 6

// debug settings (if any)
//#define DEBUG_SOFTWARE_SERIAL 1
//#define DEBUG_SERIAL 1
#define DEBUG_TO_RING_BUFFER 1


// debug methods
#ifdef DEBUG_SOFTWARE_SERIAL
//SoftwareSerial dbgSerial =  SoftwareSerial(dbgrxpin, dbgtxpin);
#endif

#ifdef DEBUG_TO_RING_BUFFER
SoftwareSerial dbgSerial =  SoftwareSerial(dbgrxpin, dbgtxpin);
RingBuffer ringBuffer = RingBuffer(RING_BUFFER_SIZE, &dbgSerial);
#endif

//macros
#define EEPROMUpdate(address,value) do {\
    byte current = EEPROM.read(address);\
    if (current != value) {\
      EEPROM.write(address,value);\
    }\
  } while (false);


// debug macros
#ifdef DEBUG_SOFTWARE_SERIAL

#define DEBUG_OUT(param) do {\
    dbgSerial.println(param);\
  } while (false);

#define DEBUG_OUT_INLINE(param) do {\
    dbgSerial.print(param);\
  } while (false);

#endif



#ifdef DEBUG_SERIAL

#define DEBUG_OUT(param) do {\
    Serial.println(param);\
  } while (false);

#define DEBUG_OUT_INLINE(param) do {\
    Serial.print(param);\
  } while (false);

#endif



#ifdef DEBUG_TO_RING_BUFFER

#define DEBUG_OUT(param) do {\
    ringBuffer.println(param);\
  } while (false);

#define DEBUG_OUT_INLINE(param) do {\
    ringBuffer.print(param);\
  } while (false);

#endif



#ifndef DEBUG_OUT
#define DEBUG_OUT(param)
#define DEBUG_OUT_INLINE(param)
#endif




// key state variables
volatile boolean lampOn = true;
volatile bool sentTriacPulse = true; // this should start false!
volatile int currentTriggerPoint;
static int nextTriggerPoint;

//faeries
volatile boolean fairy1On = true;
volatile int currentFairy1TriggerPoint;
volatile boolean fairy2On = true;
volatile int currentFairy2TriggerPoint;


void setup()
{
  // trigger an interrupt after a zero cross has been detected
  // Attach an Interupt to the digital pin that reads zero cross pulses
  attachInterrupt(digitalPinToInterrupt(PZCD1), zero_cross_detected, RISING);

  // fire a timer to count up after zero cross detected until the time when the triac should be fired
  Timer1.initialize(freqStep);
  Timer1.attachInterrupt(timer_tick_function, freqStep);

  // Set SSR1 pin as output
  pinMode(PSSR1, OUTPUT);
  digitalWrite(PSSR1, LOW);

  // faerie lights
  pinMode(faerieLights1, OUTPUT);
  pinMode(faerieLights2, OUTPUT);
  digitalWrite(faerieLights1, LOW);
  digitalWrite(faerieLights2, LOW);

  // set zero cross detect pin as input and engage the pullup resistor
  pinMode(PZCD1, INPUT);

  pinMode(dumpRingBufferPin, INPUT_PULLUP);
  pinMode(dbgInRecognizePin, OUTPUT);
  digitalWrite(dbgInRecognizePin, LOW);

  // rotary encoder
  pinMode(encoderPin1, INPUT);
  pinMode(encoderPin2, INPUT);
  pinMode(encoderSwitchPin, INPUT);
  digitalWrite(encoderPin1, HIGH); //turn pullup resistor on
  digitalWrite(encoderPin2, HIGH); //turn pullup resistor on
  digitalWrite(encoderSwitchPin, HIGH);

  // read most recent dimming level from EEPROM if available (virgin EEPROM address will read as 0xff)
  int triggerPointRead = EEPROM.read(saveLastTriggerPointAt);

  if (triggerPointRead > maxTriggerPoint || triggerPointRead < minTriggerPoint) {
    triggerPointRead = maxTriggerPoint;
  }

  nextTriggerPoint = triggerPointRead;
  currentTriggerPoint = triggerPointRead;

  lampOn = EEPROM.read(saveLampOnAt);
  Serial.begin(9600);
  Serial.println(F("Serial started>>"));

#ifdef DEBUG_SOFTWARE_SERIAL
  dbgSerial.begin(9600); // speed up to 57600 once tested
  DEBUG_OUT(F(">> Software serial debugger started"));
#endif

#ifdef DEBUG_TO_RING_BUFFER
  dbgSerial.begin(57600); // speed up to 57600 once tested
  DEBUG_OUT(F(">> Ring buffer started, trigger pin to dump"));
#endif

  DEBUG_OUT(F("debug session"));
}



void loop()
{
  static bool stateReportNeeded = true; // report status immediately on startup
  static bool recognising = false;
  static int serialBufferPosition = 0;
  static bool dumpRingBuffer = false;

  {
    // test with DMR1:?
    // check if serial debugging commands are available
    static char inputSerialBuffer[serialBufferSize];

    if (Serial.available()) {
      static int serialCount = 20;
      while (Serial.available() && serialCount--) {
        char c = Serial.read();

        if (recognising || c == 'D') {
          recognising = true;
          digitalWrite(dbgInRecognizePin, HIGH);
          inputSerialBuffer[serialBufferPosition] = c;
          serialBufferPosition++;
          if ((serialBufferPosition >= serialBufferSize) || (c == '\r') || (c == '\n')) {
            // null terminate the string, interpret the command and reset the buffer
            inputSerialBuffer[serialBufferPosition] = 0;

            DEBUG_OUT_INLINE(F("CMD:"));
            DEBUG_OUT(inputSerialBuffer);

            interpretSerialCommand(
              inputSerialBuffer,
              &nextTriggerPoint,
              &stateReportNeeded,
              &dumpRingBuffer);

            serialBufferPosition = 0;
            recognising = false;
            digitalWrite(dbgInRecognizePin, LOW);
          }
        } else {
          DEBUG_OUT_INLINE(F("x:"));
          DEBUG_OUT(c);
        }
      }
      serialCount = 20;
    }
  }

  {
    static int lastEncoded = 0;

    int MSB = digitalRead(encoderPin1); //MSB = most significant bit
    int LSB = digitalRead(encoderPin2); //LSB = least significant bit

    int encoded = (MSB << 1) | LSB; //converting the 2 pin value to single number
    int sum  = (lastEncoded << 2) | encoded; //adding it to the previous encoded value

    if (sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) {

      nextTriggerPoint += brightnessStep;

      if (nextTriggerPoint > maxTriggerPoint) {
        nextTriggerPoint = maxTriggerPoint;
      }
    }

    if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) {

      nextTriggerPoint -= brightnessStep;

      if (nextTriggerPoint < minTriggerPoint) {
        nextTriggerPoint = minTriggerPoint;
      }
    }

    lastEncoded = encoded; //store this value for next time
  }

  {
    static int lastEncoderSwitchPinValue = false;
    int encoderSwitchPinValue = digitalRead(encoderSwitchPin);

    if (lastEncoderSwitchPinValue != encoderSwitchPinValue) {
      delayMicroseconds(2000);
      if (!encoderSwitchPinValue) {
        // button is depressed
        if (lampOn) {
          turnOff(&stateReportNeeded);
        } else {
          turnOn(&stateReportNeeded);
        }
      }
      lastEncoderSwitchPinValue = encoderSwitchPinValue;
    }

#ifdef DEBUG_TO_RING_BUFFER
    if (!digitalRead(dumpRingBufferPin)) {
      // dump now
      ringBuffer.dumpBuffer();
    }

    if (dumpRingBuffer) {
      ringBuffer.dumpBuffer();
      dumpRingBuffer = false;
    }
#endif
  }

  if (sentTriacPulse) {

    if (currentTriggerPoint != nextTriggerPoint) {
      currentTriggerPoint = nextTriggerPoint;

      // for now, faeries match main lamp
      currentFairy1TriggerPoint = nextTriggerPoint;
      currentFairy2TriggerPoint = nextTriggerPoint;

      // save the eeprom update on the "main thread", in due course
      EEPROMUpdate(saveLastTriggerPointAt, nextTriggerPoint);
      stateReportNeeded = true;
    }

    if (stateReportNeeded) {
      DEBUG_OUT(F("reporting status"));

      writeStatus();
      stateReportNeeded = false;
    }

    sentTriacPulse = false; // this must reset to false!
  }
}


