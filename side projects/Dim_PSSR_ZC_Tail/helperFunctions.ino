#define outputBufferSize 10

void writeStatus() {
  static char outputSerialBuffer[outputBufferSize];
  if (lampOn) {
    snprintf(outputSerialBuffer, outputBufferSize, "DMR1=%02d\r\n", currentTriggerPoint);
  } else {
    snprintf(outputSerialBuffer, outputBufferSize, "DMR1=__\r\n");
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

void interpretSerialCommand(
char * serialBuffer,
int * triggerPointPtr,
bool * stateReportNeeded,
bool * dumpRingBuffer)
{
  if (strncmp(serialBuffer, "DMR1:", 5) == 0) {
    char * command = serialBuffer + 5;
    if (*command == '?') {
      *stateReportNeeded = true;
    } else if (*command == '_') {
      turnOff(stateReportNeeded);
    } else if (*command == 'O') {
      turnOn(stateReportNeeded);
    } else if (*command == 'X') {
      *dumpRingBuffer = true;
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
