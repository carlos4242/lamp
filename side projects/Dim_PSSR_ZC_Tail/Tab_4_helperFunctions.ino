#define outputBufferSize 10

void writeStatus() {
  static char outputSerialBuffer[outputBufferSize];
  if (lampOn) {
    snprintf(outputSerialBuffer, outputBufferSize, "DMR1=%02d\r\n", nextTriggerPoint[0]);
  } else {
    snprintf(outputSerialBuffer, outputBufferSize, "DMR1=__\r\n");
  }
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

void interpretSerialCommand(
  char * serialBuffer,
  bool * valuesNeedSave,
  bool * stateReportNeeded,
  bool * dumpRingBuffer)
{
  if (strncmp(serialBuffer, "DMR1:", 5) == 0) {
    char * command = serialBuffer + 5;
    if (*command == '?') {
      *stateReportNeeded = true;
    } else if (*command == '_') {
      turnOff();
      *stateReportNeeded = true;
    } else if (*command == 'O') {
      turnOn();
      *stateReportNeeded = true;
    } else if (*command == 'X') {
      *dumpRingBuffer = true;
    } else {
      turnOn();
      int newTriggerPointVal = atoi(command);

      if (newTriggerPointVal) {
        if (newTriggerPointVal > maxTriggerPoint) {
          newTriggerPointVal = maxTriggerPoint;
        } else if (newTriggerPointVal < minTriggerPoint) {
          newTriggerPointVal = minTriggerPoint;
        }
        
        nextTriggerPoint[0] = newTriggerPointVal;
        *valuesNeedSave = true;
      }
    }
  }
}
