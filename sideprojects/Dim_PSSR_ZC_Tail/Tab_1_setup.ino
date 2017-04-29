void setup()
{
  // set zero cross detect pin as input and engage the pullup resistor
  pinMode(PZCD1, INPUT_PULLUP);

  // Set SSR1 pin as output
  pinMode(PSSR1, OUTPUT);

  // faerie lights
  pinMode(faerieLights1, OUTPUT);
  pinMode(faerieLights2, OUTPUT);

  // rotary encoder
  pinMode(encoderPin1, INPUT_PULLUP);
  pinMode(encoderPin2, INPUT_PULLUP);
  pinMode(encoderSwitchPin, INPUT_PULLUP);

#ifdef DEBUG_TO_RING_BUFFER
  pinMode(dumpRingBufferPin, INPUT_PULLUP);
#endif

#ifdef DEBUG_IN_RECOGNIZE
  pinMode(dbgInRecognizePin, OUTPUT);
#endif

#ifdef DEBUG_IN_TIMER_ISR
  pinMode(dbgInTimerISR, OUTPUT);
#endif

#ifdef DEBUG_IN_ZERO_X_ISR
  pinMode(dbgInZeroCrossISR, OUTPUT);
#endif

  // Initialise serial ports

  Serial.begin(9600);
  Serial.println(F("Serial started>>"));

  // read stored values
  
  readTriggerPoints();

  lampOn = EEPROM.read(saveLampOnAt);

#ifdef DEBUG_SOFTWARE_SERIAL
  dbgSerial.begin(9600); // speed up to 57600 once tested
  DEBUG_OUT(F(">> Software serial debugger started"));
#endif

#ifdef DEBUG_TO_RING_BUFFER
  dbgSerial.begin(57600); // speed up to 57600 once tested
  DEBUG_OUT(F(">> Ring buffer started, trigger pin to dump"));
#endif

  DEBUG_OUT(F("debug session"));


  /* START TIMERS AND INTERRUPT HANDLERS */

  // trigger an interrupt after a zero cross has been detected
  // Attach an Interupt to the digital pin that reads zero cross pulses
  attachInterrupt(digitalPinToInterrupt(PZCD1), zero_cross_detected, RISING);

  // fire a timer to count up after zero cross detected until the time when the triac should be fired
  Timer1.initialize(tickTimerPeriod);
  Timer1.attachInterrupt(timer_tick_function, tickTimerPeriod);
}
