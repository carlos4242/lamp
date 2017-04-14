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

// debug settings (if any)
//#define DEBUG_SOFTWARE_SERIAL 1
//#define DEBUG_SERIAL 1
//#define DEBUG_TO_RING_BUFFER 1
//#define DEBUG_IN_RECOGNIZE 1
#define DEBUG_IN_ZERO_X_ISR 1
#define DEBUG_IN_TIMER_ISR 1

// constants
#define RING_BUFFER_SIZE 500
#define saveLastTriggerPointAt 0x31
#define saveLampOnAt 0x32

// brightness works by waiting a specific period after zero cross then triggering the triac or SCR
// the period is defined as a number of brightness steps, from minTriggerPoint (brightest) to maxTriggerPoint (dimmest)
// each step is approximately 0.1ms, (100us)
#define minTriggerPoint 5
#define maxTriggerPoint 90
#define brightnessStep 1
#define ticksPerBrightnessStep 3
#define minimumTickCount 40
#define serialBufferSize 9 // the maximum length of the serial input/output
#define tickTimerPeriod 33 // run the timer interrupt every 33 us

// PORTD pins
// note 0 and 1 are the rx and tx from the UART and are used to communicate with the xbee so
// must be left untouched
#define PZCD1 2 // PowerSwitch Zero detect on this pin (must be interrupt capable)

#define encoderSwitchPin 3 // rotary encoder push switch

#define PSSR1 4 // PowerSSR Tail connected to this digital pin to control power

// faerie lights - VERY IMPORTANT!! .. the ISRs change these by direct port write
// be very careful with this code and make sure it all matches!
// for example, currently the ISR is written to manipulate PORTD, meaning that these
// pins can only take values from 0-7.  And 0 or 1 would be mad as those are rx/tx on the
// serial UART, connected to the Xbee
// Also, these pins must be set in setup to be OUTPUT pins.  And ideally initialised there using a
// regular digitalWrite function, just for safety
#define faerieLights1 5
#define faerieLights2 6

#define encoderPin1 7 // rotary encoder pin1


// PORTB pins
#define PORT_B_BASE 8

#define encoderPin2 8 // rotary encoder pin2

#ifdef DEBUG_TO_RING_BUFFER
#define dbgrxpin 9
#define dbgtxpin 10
#define dumpRingBufferPin 11
#endif


#ifdef DEBUG_IN_TIMER_ISR
#define dbgInTimerISR 12
#endif

#ifdef DEBUG_IN_ZERO_X_ISR
#define dbgInZeroCrossISR 13
#endif

#ifdef DEBUG_IN_RECOGNIZE
#define dbgInRecognizePin 13
#endif




// debug methods
#ifdef DEBUG_SOFTWARE_SERIAL
SoftwareSerial dbgSerial =  SoftwareSerial(dbgrxpin, dbgtxpin);
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

#define numberLamps 3



// key state variables
// note that any that can be read/written to by an ISR is marked volatile to avoid compiler making assumptions
volatile boolean lampOn; // for the main lamp we have an on/off, for the fairy lights, we just set them to <maxTriggerPoint> to turn them off
volatile bool sentTriacPulse = true; // this should start false!
// these are temporary holding places for updating the trigger points on the next cycle, it's done after the triac/scr pulses because we don't want a glitch
volatile static int nextTriggerPoint[numberLamps];
