#include <inttypes.h>
#include "Print.h"

class RingBuffer : public Print {
  private:
    size_t bufferSize;
    char * ringBuffer;
    int currentRingBufferPosition = 0;
    int charactersLogged = 0;
    Print * dumpDestination;
  public:
    RingBuffer(size_t bufSize, Print * dumpDest);
    ~RingBuffer();
    virtual size_t write(uint8_t);
//    virtual size_t write(const char *str);
//    virtual size_t write(const uint8_t *buffer, size_t size);
    void dumpBuffer();
};
