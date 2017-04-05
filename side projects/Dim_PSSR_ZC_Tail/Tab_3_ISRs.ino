void fireTriac() {
  digitalWrite(PSSR1, HIGH);
  delayMicroseconds(200); // was 500, try a shorter pulse...
  digitalWrite(PSSR1, LOW);
}

void resetFaeries() {
  digitalWrite(faerieLights1, LOW);
  digitalWrite(faerieLights2, LOW);
}

void fireFaerieSCR1() {
  digitalWrite(faerieLights1, HIGH);
}

void fireFaerieSCR2() {
  digitalWrite(faerieLights2, HIGH);
}


// ISRs
// All these functions are ISRs, be wary of volatile variables, side effects and speed

// Timer tick function.
// This function will wait for zero cross, then after that, increment a counter on each tick until the proper time,
// then finally fire the triac, reset the zero_cross flag and counter, ready for the next zero cross.

volatile boolean triac_pulse_due = false; // Boolean to store a "switch" to tell us if we have crossed zero
volatile boolean faery_1_enable_due = false; // Boolean to store a "switch" to tell us if we have crossed zero
volatile boolean faery_2_enable_due = false; // Boolean to store a "switch" to tell us if we have crossed zero

volatile static int triacTickCount = 0;
volatile static int fairy1TickCount = 0;
volatile static int fairy2TickCount = 0;

volatile int currentTriggerPoint[numberLamps];

void timer_tick_function() {
  PORTB |= B10000; // using a fast port write to save time, but isn't very safe... equivalent to... digitalWrite(dbgInTimerISR, HIGH);

  if (triac_pulse_due) {
    // count the number of interrupts fired by the timer since the last zero cross
    if (triacTickCount < currentTriggerPoint[0] * brightnessMultiplier) {
      triacTickCount++;
    } else {
      triac_pulse_due = false; // disable until the next zero cross

      if (lampOn) {
        fireTriac();
      }

      currentTriggerPoint[0] = nextTriggerPoint[0];
      sentTriacPulse = true;
    }
  }

  if (faery_1_enable_due) {
    if (fairy1TickCount < currentTriggerPoint[1] * brightnessMultiplier) {
      fairy1TickCount++;
    } else {
      faery_1_enable_due = false;
      fireFaerieSCR1();
      currentTriggerPoint[1] = nextTriggerPoint[1];
    }
  }

  if (faery_2_enable_due) {
    if (fairy2TickCount < currentTriggerPoint[2] * brightnessMultiplier) {
      fairy2TickCount++;
    } else {
      faery_2_enable_due = false;
      fireFaerieSCR2();
      currentTriggerPoint[2] = nextTriggerPoint[2];
    }
  }

  PORTB &= ~B10000; // equivalent to... digitalWrite(dbgInTimerISR, LOW);
}

void zero_cross_detected()
{
  // PORTB |= B100000;
  
  triacTickCount = 0;
  fairy1TickCount = 0;
  fairy2TickCount = 0;

  triac_pulse_due = true;
  faery_1_enable_due = true;
  faery_2_enable_due = true;

  // prevent main loop action from occurring until after next zero cross cycle is complete
  // the reason for this is the main loop processing can be heavy and tie up the processor somewhat
  // so it's important we leave it until after the triac pulse has been cleanly sent at exactly
  // the right time
  // that's less important for faery stuff as any jitter is far less noticeable
  sentTriacPulse = false;
  resetFaeries();
  
  // PORTB &= ~B100000;
}
