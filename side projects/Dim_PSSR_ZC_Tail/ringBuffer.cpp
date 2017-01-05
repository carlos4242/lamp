#include "ringBuffer.h"

static char * oversizeMessage = "<<OVERSIZE>>";
static size_t oversizeMessageLen = 12;
static char * bufferTerminator = "<<<";
static size_t bufferTerminatorLen = 3;

__attribute__((constructor))
static void initialize_string_lengths() {
  oversizeMessageLen = strlen(oversizeMessage);
  bufferTerminatorLen = strlen(bufferTerminator);
}

RingBuffer::RingBuffer(size_t bufSize) {
  if (bufSize > 500) {
    // too big
    bufSize = 500;
  } else if (bufSize<oversizeMessageLen) {
    bufSize = oversizeMessageLen; // minimum to avoid a rare buffer overflow bug
  }
  bufferSize = bufSize;
  ringBuffer = (char*)malloc(bufSize);
}

RingBuffer::~RingBuffer() {
  free(ringBuffer);
}

void RingBuffer::dumpBuffer(Print * dumpDestination) {
  if (!charactersLogged) return;

  if (!ringBuffer) {
    dumpDestination->println(F("ring buffer was NEVER INITIALISED!"));
  }

  dumpDestination->println(F("ring buffer:"));
  dumpDestination->print(charactersLogged);
  dumpDestination->println(F(" bytes logged"));
  dumpDestination->print(bufferSize);
  dumpDestination->println(F(" buffer size"));
  dumpDestination->print(currentRingBufferPosition);
  dumpDestination->println(F(" buffer end"));
  
  if (currentRingBufferPosition < bufferSize - bufferTerminatorLen) {
    strncpy(ringBuffer + currentRingBufferPosition, bufferTerminator, bufferTerminatorLen);
    charactersLogged+=bufferTerminatorLen;
  }
  
  if (charactersLogged < bufferSize) {
    dumpDestination->write(ringBuffer, charactersLogged);
  } else {
    dumpDestination->write(ringBuffer, bufferSize);
  }
  
  charactersLogged = 0;
  currentRingBufferPosition = 0;
}

size_t RingBuffer::write(uint8_t character) {
  if (!ringBuffer) return 0;

  if (currentRingBufferPosition<bufferSize-1) {
    ringBuffer[currentRingBufferPosition] = character;
    currentRingBufferPosition++;
  } else {
    ringBuffer[0] = character;
    currentRingBufferPosition = 0;
  }
  charactersLogged++;
  return 1;
}

// for now, leave the fancy versions commented out, only when the buffer is working, gradually reintroduce them
//size_t RingBuffer::write(const char *msg) {
//  if (!ringBuffer) return 0;
//  
//  size_t msgLen = strlen(msg);
//  if (msgLen > bufferSize) {
//    // should never happen but just in case
//    msg = oversizeMessage;
//    msgLen = oversizeMessageLen;
//  }
//  
//  int remainingBuffer = bufferSize - currentRingBufferPosition;
//  
//  if (remainingBuffer > msgLen) {
//    strncpy(ringBuffer + currentRingBufferPosition, msg, msgLen);
//    currentRingBufferPosition += msgLen;
//  } else {
//    // loop back to the start
//    strncpy(ringBuffer + currentRingBufferPosition, msg, remainingBuffer);
//    currentRingBufferPosition = msgLen - remainingBuffer;
//    strncpy(ringBuffer, msg + remainingBuffer, currentRingBufferPosition);
//  }
//  charactersLogged += msgLen;
//  return msgLen;
//}
//
//size_t RingBuffer::write(const uint8_t *buffer, size_t size) {
//  if (!ringBuffer) return 0;
//  
//  if (size > bufferSize) {
//    // should never happen but just in case
//    strncpy(buffer,oversizeMessage,oversizeMessageLen);
//    size = oversizeMessageLen;
//  }
//  
//  int remainingBuffer = bufferSize - currentRingBufferPosition;
//  
//  if (remainingBuffer > size) {
//    strncpy(ringBuffer + currentRingBufferPosition, buffer, size);
//    currentRingBufferPosition += size;
//  } else {
//    // loop back to the start
//    strncpy(ringBuffer + currentRingBufferPosition, buffer, remainingBuffer);
//    currentRingBufferPosition = size - remainingBuffer;
//    strncpy(ringBuffer, buffer + remainingBuffer, currentRingBufferPosition);
//  }
//  charactersLogged += size;
//  return size;
//}
