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
  pinMode(dbgInTimerISR, OUTPUT);
  digitalWrite(dbgInTimerISR,HIGH);

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
