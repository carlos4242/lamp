#define outputBufferSize 10

void writeStatus() {
  static char outputSerialBuffer[outputBufferSize];

  if (lampOn) {
    snprintf(outputSerialBuffer, outputBufferSize, "DMR1=%02d\r\n", nextTriggerPoint[0]);
  } else {
    snprintf(outputSerialBuffer, outputBufferSize, "DMR1=__\r\n");
  }

  Serial.write(outputSerialBuffer);

  snprintf(outputSerialBuffer, outputBufferSize, "DMR2=%02d\r\n", nextTriggerPoint[1]);
  Serial.write(outputSerialBuffer);

  snprintf(outputSerialBuffer, outputBufferSize, "DMR3=%02d\r\n", nextTriggerPoint[2]);
  Serial.write(outputSerialBuffer);
}

void changeTriggerPoint(int triggerNumber, int increment) {
  int triggerPoint = nextTriggerPoint[triggerNumber];
  triggerPoint += increment;

  if (triggerPoint > maxTriggerPoint) {
    triggerPoint = maxTriggerPoint;
  } else if (triggerPoint < minTriggerPoint) {
    triggerPoint = minTriggerPoint;
  }

  nextTriggerPoint[triggerNumber] = triggerPoint;
}

void turnOff() {
  if (lampOn) {
    lampOn = false;
    EEPROMUpdate(saveLampOnAt, lampOn);
  }
}

void turnOn() {
  if (!lampOn) {
    lampOn = true;
    EEPROMUpdate(saveLampOnAt, lampOn);
  }
}

void readTriggerPoints() {
  // read most recent dimming level from EEPROM if available (virgin EEPROM address will read as 0xff)

  for (int i = 0; i < numberLamps; i++) {
    int triggerPointRead = EEPROM.read(saveLastTriggerPointAt + i);
    //  Serial.print(F("Loaded brightness:"));
    //  Serial.println(triggerPointRead);

    if (triggerPointRead > maxTriggerPoint || triggerPointRead < minTriggerPoint) {
      triggerPointRead = maxTriggerPoint;
    }

    nextTriggerPoint[i] = triggerPointRead;
  }
}

void saveTriggerPoints() {
  // save the eeprom update on the "main thread"
  //      EEPROMUpdate(saveLastTriggerPointAt, nextTriggerPoint[0]); // for now we are only saving the main lamp value

  for (int i = 0; i < numberLamps; i++) {
    EEPROMUpdate(saveLastTriggerPointAt + i, nextTriggerPoint[i]);
  }
}

void interpretSerialCommand(
  char * serialBuffer,
  bool * valuesNeedSave,
  bool * stateReportNeeded,
  bool * dumpRingBuffer)
{
  if (strnlen(serialBuffer, serialBufferSize) < 6) return; // prevent any possibility of buffer bounds breach

  if (strncmp(serialBuffer, "DMR", 3) == 0 && serialBuffer[4] == ':') {
    char dimmerNumberBuf[2];
    dimmerNumberBuf[0] = serialBuffer[3];
    dimmerNumberBuf[1] = 0;
    DEBUG_OUT_INLINE(F("dimmerNumberBuf:"));
    DEBUG_OUT(dimmerNumberBuf);
    int dimmerNumber = atoi(dimmerNumberBuf);
    DEBUG_OUT_INLINE(F("dimmerNumber:"));
    DEBUG_OUT(dimmerNumber);

    char * command = serialBuffer + 5;
    if (*command == '?') {
      *stateReportNeeded = true;
    } else if (*command == '_') {
      if (dimmerNumber == 1) {
        turnOff();
      }
    } else if (*command == 'O') {
      if (dimmerNumber == 1) {
        turnOn();
      }
    } else if (*command == 'X') {
      *dumpRingBuffer = true;
    } else {
      int newTriggerPointVal = atoi(command);

      if (newTriggerPointVal && dimmerNumber && dimmerNumber < 4) {
        DEBUG_OUT_INLINE(F("newTriggerPointVal:"));
        DEBUG_OUT(newTriggerPointVal);
        if (dimmerNumber == 1) {
          turnOn();
        }

        if (newTriggerPointVal > maxTriggerPoint) {
          newTriggerPointVal = maxTriggerPoint;
        } else if (newTriggerPointVal < minTriggerPoint) {
          newTriggerPointVal = minTriggerPoint;
        }

        nextTriggerPoint[dimmerNumber - 1] = newTriggerPointVal;
        *valuesNeedSave = true;
      }
    }
  }
}
