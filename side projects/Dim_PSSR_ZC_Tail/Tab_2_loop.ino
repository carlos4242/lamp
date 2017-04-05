void loop()
{
  static bool stateReportNeeded = true; // report status immediately on startup
  static bool recognising = false;
  static int serialBufferPosition = 0;
  static bool dumpRingBuffer = false;
  static bool valuesNeedSave = false;

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
              &valuesNeedSave,
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
      changeTriggerPoint(0, brightnessStep);
      changeTriggerPoint(1, brightnessStep);
      changeTriggerPoint(2, brightnessStep);
      valuesNeedSave = true;
    }

    if (sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) {
      changeTriggerPoint(0, -brightnessStep);
      changeTriggerPoint(1, -brightnessStep);
      changeTriggerPoint(2, -brightnessStep);
      valuesNeedSave = true;
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
          turnOff();
        } else {
          turnOn();
        }
        stateReportNeeded = true;
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

    if (valuesNeedSave) {
      // save the eeprom update on the "main thread"
      EEPROMUpdate(saveLastTriggerPointAt, nextTriggerPoint[0]); // for now we are only saving the main lamp value
      stateReportNeeded = true;
      valuesNeedSave = false;
    }

    if (stateReportNeeded) {
      DEBUG_OUT(F("reporting status"));

      writeStatus();
      stateReportNeeded = false;
    }

    sentTriacPulse = false; // this must reset to false!
  }
}
