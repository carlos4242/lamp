#include <EEPROM.h>
#include <TimerOne.h>
#include <stdlib.h>

#define EEPROMUpdate(address,value) do {\
    byte current = EEPROM.read(address);\
    if (current != value) {\
      EEPROM.write(address,value);\
    }\
  } while (false);

bool serialStarted = false;

#define DEBUG_OUT(param) do {\
    if (serialStarted) {\
      Serial.println(param);\
    }\
  } while (false);


/*
 Dim_PSSR_ZC_Tail

 This sketch is a sample sketch using the ZeroCross Tail(ZCT) to generate a sync
 pulse to drive a PowerSSR Tail(PSSRT) for dimming ac lights.

 Connections to an Arduino Duemilanove:
 1. Connect the C terminal of the ZeroCross Tail to digital pin 2 with a 10K ohm pull up to Arduino 5V.
 2. Connect the E terminal of the ZeroCross Tail to Arduino Gnd.
 3. Connect the PowerSSR Tail +in terminal to digital pin 4 and the -in terminal to Gnd.
   http://bildr.org/2012/08/rotary-encoder-arduino/
*/

#define saveLastTriggerPointAt 0x31
#define saveLampOnAt 0x32
#define minTriggerPoint 5
#define maxTriggerPoint 90
#define brightnessStep 1
#define brightnessMultiplier 10

#define serialBufferSize 12 // the maximum length of the serial input/output
// PowerSwitch Zero detect on this pin (must be interrupt capable)
#define PZCD1 2
// PowerSSR Tail connected to this digital pin to control power
#define PSSR1 4
// Set to 50hz mains
#define freqStep 10


// rotary encoder support (including push switch):
#define encoderPin1 7
#define encoderPin2 8
#define encoderSwitchPin 3

volatile boolean lampOn = true;
volatile bool sentPulse = true; // this should start false!
volatile int currentTriggerPoint;
static int nextTriggerPoint;
volatile boolean zero_cross = false; // Boolean to store a "switch" to tell us if we have crossed zero

void setup()
{
  // trigger an interrupt after a zero cross has been detected
  attachInterrupt(digitalPinToInterrupt(PZCD1), zero_cross_detect, RISING);   // Attach an Interupt to the digital pin that reads zero cross pulses

  // fire a timer to count up after zero cross detected until the time when the triac should be fired
  Timer1.initialize(freqStep);
  Timer1.attachInterrupt(timer_tick_function, freqStep);

  // Set SSR1 pin as output
  pinMode(PSSR1, OUTPUT);

  // set zero cross detect pin as input and engage the pullup resistor
  pinMode(PZCD1, INPUT);

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
}

void writeStatus() {
  if (!serialStarted) return;

  static char outputSerialBuffer[serialBufferSize];
  if (lampOn) {
    snprintf(outputSerialBuffer, serialBufferSize, "DMR1=%d\n", currentTriggerPoint);
  } else {
    snprintf(outputSerialBuffer, serialBufferSize, "DMR1=_\n");
  }
  Serial.write(outputSerialBuffer);
}

void turnOff(bool * stateReportNeeded) {
  if (lampOn) {
    lampOn = false;
    *stateReportNeeded = true;
    EEPROMUpdate(saveLampOnAt, lampOn);
  }
}

void turnOn(bool * stateReportNeeded) {
  if (!lampOn) {
    lampOn = true;
    *stateReportNeeded = true;
    EEPROMUpdate(saveLampOnAt, lampOn);
  }
}

void interpretSerialCommand(char * serialBuffer, int * triggerPointPtr, bool * stateReportNeeded) {  
  if (strncmp(serialBuffer, "DMR1:", 5) == 0) {
    char * command = serialBuffer + 5;
    if (*command == '?') {
      *stateReportNeeded = true;
    } else if (*command == '_') {
      turnOff(stateReportNeeded);
    } else if (*command == 'O') {
      turnOn(stateReportNeeded);
    } else {
      turnOn(stateReportNeeded);
      int newTriggerPointVal = atoi(command);
      if (newTriggerPointVal > maxTriggerPoint) {
        newTriggerPointVal = maxTriggerPoint;
      } else if (newTriggerPointVal < minTriggerPoint) {
        newTriggerPointVal = minTriggerPoint;
      }
      *triggerPointPtr = newTriggerPointVal;
    }
  }
}

void fireTriac() {
  digitalWrite(PSSR1, HIGH);
  delayMicroseconds(500);
  digitalWrite(PSSR1, LOW);
}

void loop()
{
  static bool stateReportNeeded = false;

  if (serialStarted) {
    // test with DMR1:?
    static int serialBufferPosition = 0;
    // check if serial debugging commands are available
    static char inputSerialBuffer[serialBufferSize];
    if (Serial.available()) {
      char c = Serial.read();
      inputSerialBuffer[serialBufferPosition] = c;
      serialBufferPosition++;
      if ((serialBufferPosition >= serialBufferSize) || (c == '\r')) {
        // null terminate the string, interpret the command and reset the buffer
        inputSerialBuffer[serialBufferPosition] = 0;
//        DEBUG_OUT(nextTriggerPoint);
        interpretSerialCommand(inputSerialBuffer, &nextTriggerPoint, &stateReportNeeded);
//        DEBUG_OUT(nextTriggerPoint);
        serialBufferPosition = 0;
      }
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
  }

  if (sentPulse) {

    if (!serialStarted) {
      Serial.begin(9600);
      serialStarted = true;
      DEBUG_OUT(F(">>Serial Started"));
    }

    if (currentTriggerPoint != nextTriggerPoint) {
      currentTriggerPoint = nextTriggerPoint;
      // save the eeprom update on the "main thread", in due course
      EEPROMUpdate(saveLastTriggerPointAt, nextTriggerPoint);
      stateReportNeeded = true;
    }

    if (stateReportNeeded) {
      writeStatus();
      stateReportNeeded = false;
    }

//    sentPulse = false; // this must reset to false!
  }
}

// ISRs
// All these functions are ISRs, be wary of volatile variables, side effects and speed

// Timer tick function.
// This function will wait for zero cross, then after that, increment a counter on each tick until the proper time,
// then finally fire the triac, reset the zero_cross flag and counter, ready for the next zero cross.
volatile static int i = 0; // count the number of interrupts fired by the timer since the last zero cross
void timer_tick_function() {

  if (!lampOn) return;

  if (!zero_cross) return; // waiting for zero cross

  if (i < currentTriggerPoint*brightnessMultiplier) {
    i++;
  } else {
    zero_cross = false; // disable until the next zero cross
    fireTriac();
    sentPulse = true;
  }
}

void zero_cross_detect()
{
  i = 0;
  zero_cross = true;
  sentPulse = false; // prevent main loop action from occurring until after next zero cross cycle is complete
}
