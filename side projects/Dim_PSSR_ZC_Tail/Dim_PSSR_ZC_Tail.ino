#include <EEPROM.h>
#include <TimerOne.h>
#include <stdlib.h>
#define EEPROMUpdate(address,value) do {\
    byte current = EEPROM.read(address);\
    if (current != value) {\
      EEPROM.write(address,value);\
    }\
  } while (false);
#define DEBUG_OUT(param) Serial.println(param)


/*
 Dim_PSSR_ZC_Tail

 This sketch is a sample sketch using the ZeroCross Tail(ZCT) to generate a sync
 pulse to drive a PowerSSR Tail(PSSRT) for dimming ac lights.

 Connections to an Arduino Duemilanove:
 1. Connect the C terminal of the ZeroCross Tail to digital pin 2 with a 10K ohm pull up to Arduino 5V.
 2. Connect the E terminal of the ZeroCross Tail to Arduino Gnd.
 3. Connect the PowerSSR Tail +in terminal to digital pin 4 and the -in terminal to Gnd.
*/

#define saveLastTriggerPointAt 0x31
#define saveLampOnAt 0x32
#define minTriggerPoint 5
#define maxTriggerPoint 120
#define serialBufferSize 12 // the maximum length of the serial input/output
// PowerSwitch Zero detect on this pin (must be interrupt capable)
#define PZCD1 2
// PowerSSR Tail connected to this digital pin to control power
#define PSSR1 4
// Set to 60hz mains
#define freqStep 60


// rotary encoder support:
#define encoderPin1 7
#define encoderPin2 8
//push button switch
#define encoderSwitchPin 3

// dimmer state
// level (0-128)  0 = on, 128 = off
volatile int triggerPoint = minTriggerPoint;
volatile boolean lampOn = true;

// serial buffer/state and flags
char serialBuffer[serialBufferSize];
bool stateSaveNeeded = false;
bool stateReportNeeded = false;


void setup()
{
  // trigger an interrupt after a zero cross has been detected
  attachInterrupt(digitalPinToInterrupt(PZCD1), zero_cross_detect, RISING);   // Attach an Interupt to the digital pin that reads zero cross pulses

  // fire a timer to count up after zero cross detected until the time when the triac should be fired
  Timer1.initialize(freqStep);
  Timer1.attachInterrupt(triggerPoint_check, freqStep);

  // Set SSR1 pin as output
  pinMode(PSSR1, OUTPUT);

  // rotary encoder
  pinMode(encoderPin1, INPUT);
  pinMode(encoderPin2, INPUT);
  pinMode(encoderSwitchPin, INPUT);
  digitalWrite(encoderPin1, HIGH); //turn pullup resistor on
  digitalWrite(encoderPin2, HIGH); //turn pullup resistor on
  digitalWrite(encoderSwitchPin, HIGH);
  attachInterrupt(digitalPinToInterrupt(encoderPin1), updateEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(encoderPin2), updateEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(encoderSwitchPin), encoderButtonPressed, CHANGE);

  // read most recent dimming level from EEPROM if available (virgin EEPROM address will read as 0xff)
  triggerPoint = EEPROM.read(saveLastTriggerPointAt);
  if (triggerPoint > maxTriggerPoint || triggerPoint < minTriggerPoint) {
    triggerPoint = maxTriggerPoint;
  }
  lampOn = EEPROM.read(saveLampOnAt);

  // serial support
  Serial.begin(9600);
  memset(serialBuffer, 0, serialBufferSize);

  // tell the world we are alive
  DEBUG_OUT(F(">>Started"));
}

void writeStatus() {
  if (lampOn) {
    snprintf(serialBuffer, serialBufferSize, "DMR1=%d\n", triggerPoint);
  } else {
    snprintf(serialBuffer, serialBufferSize, "DMR1=_\n");
  }
  Serial.write(serialBuffer);
}

void turnOff() {
  lampOn = false;
}

void turnOn() {
  lampOn = true;
}

void encoderSwitchPressHandler() {
  if (lampOn) {
    turnOff();
  } else {
    turnOn();
  }

  stateSaveNeeded = true;
  stateReportNeeded = true;

  attachInterrupt(digitalPinToInterrupt(encoderSwitchPin), encoderButtonPressed, CHANGE);
}

void interpretSerialCommand() {
  if (strncmp(serialBuffer, "DMR1:", 5) == 0) {
    char * command = serialBuffer + 5;
    if (*command == '?') {
      stateReportNeeded = true;
    } else if (*command == '_') {
      turnOff();
      stateSaveNeeded = true;
    } else if (*command == 'O') {
      turnOn();
      stateSaveNeeded = true;
    } else {
      turnOn();
      int newTriggerPoint = atoi(command);
      if (newTriggerPoint > maxTriggerPoint) {
        newTriggerPoint = maxTriggerPoint;
      } else if (newTriggerPoint < minTriggerPoint) {
        newTriggerPoint = minTriggerPoint;
      }
      triggerPoint = newTriggerPoint;
      stateSaveNeeded = true;
    }
  }
}

volatile bool encoderSwitchPressed = false;

void loop()
{ // test with DMR1:?
  static int serialBufferPosition = 0;
  // check if serial debugging commands are available
  if (Serial.available()) {
    char c = Serial.read();
    serialBuffer[serialBufferPosition] = c;
    serialBufferPosition++;
    if ((serialBufferPosition >= serialBufferSize) || (c == '\r')) {
      // null terminate the string, interpret the command and reset the buffer
      serialBuffer[serialBufferPosition] = 0;
      interpretSerialCommand();
      memset(serialBuffer, 0, serialBufferPosition);
      serialBufferPosition = 0;
    }
  }

  if (encoderSwitchPressed) {
    encoderSwitchPressHandler();
    encoderSwitchPressed = false; // reset flag
  }

  if (stateSaveNeeded) {
    // save the eeprom update on the "main thread", in due course
    EEPROMUpdate(saveLastTriggerPointAt, triggerPoint);
    EEPROMUpdate(saveLampOnAt, lampOn);
    stateSaveNeeded = false;
  }

  if (stateReportNeeded) {
    writeStatus();
  }
}

// ISRs
// All these functions are ISRs, be wary of volatile variables, side effects and speed

void updateEncoder() {
  // http://bildr.org/2012/08/rotary-encoder-arduino/
  volatile static int lastEncoded = 0;
  int MSB = digitalRead(encoderPin1); //MSB = most significant bit
  int LSB = digitalRead(encoderPin2); //LSB = least significant bit

  int encoded = (MSB << 1) | LSB; //converting the 2 pin value to single number
  int sum  = (lastEncoded << 2) | encoded; //adding it to the previous encoded value

  if (sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) {
    triggerPoint ++;
    if (triggerPoint > maxTriggerPoint) {
      triggerPoint = maxTriggerPoint;
    }
  }
  if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) {
    triggerPoint --;
    if (triggerPoint < minTriggerPoint) {
      triggerPoint = minTriggerPoint;
    }
  }

  lastEncoded = encoded; //store this value for next time
}

void encoderButtonPressed() {
  detachInterrupt(digitalPinToInterrupt(encoderSwitchPin)); // avoid debounce
  encoderSwitchPressed = true;
}

volatile boolean zero_cross = false; // Boolean to store a "switch" to tell us if we have crossed zero

// This function will fire the triac at the proper time
void triggerPoint_check() {
  // First check to make sure the zero-cross has happened and the light should be on else do nothing
  if (zero_cross && lampOn) {
    volatile static int i = 0; // count the number of interrupts fired by the timer since the last zero cross
    if (i >= triggerPoint) {
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
