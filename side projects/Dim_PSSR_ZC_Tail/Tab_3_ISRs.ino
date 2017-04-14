inline void fireTriac() {
  PORTD |= _BV(PSSR1);
  delayMicroseconds(200); // was 500, try a shorter pulse...
  PORTD &= ~_BV(PSSR1);
}

inline void resetFaeries() {
  PORTD &= ~_BV(faerieLights1) & ~_BV(faerieLights2);
}

inline void fireFaerieSCR1() {
  PORTD |= _BV(faerieLights1);
}

inline void fireFaerieSCR2() {
  PORTD |= _BV(faerieLights2);
}

// ISRs
// All these functions are ISRs, be wary of volatile variables, side effects and speed

// Timer tick function.
// This function will wait for zero cross, then after that, increment a counter on each tick until the proper time,
// then finally fire the triac, reset the zero_cross flag and counter, ready for the next zero cross.

volatile boolean triac_pulse_due = false; // Boolean to store a "switch" to tell us if we have crossed zero
volatile boolean faery_1_enable_due = false; // Boolean to store a "switch" to tell us if we have crossed zero
volatile boolean faery_2_enable_due = false; // Boolean to store a "switch" to tell us if we have crossed zero

// count of ticks since last zero cross
volatile static int tickCount = 0;

volatile int currentTriggerPoint[numberLamps];

void timer_tick_function() {
#ifdef DEBUG_IN_TIMER_ISR
  // using a fast port write to save time, but isn't very safe... equivalent to... digitalWrite(dbgInTimerISR, HIGH); // B10000
  PORTB |= _BV(dbgInTimerISR - PORT_B_BASE);
#endif

  tickCount++;

  if (faery_1_enable_due) {
    if (tickCount >= currentTriggerPoint[1] * ticksPerBrightnessStep) {
      faery_1_enable_due = false;
      fireFaerieSCR1();
      currentTriggerPoint[1] = nextTriggerPoint[1];
    }
  }

  if (faery_2_enable_due) {
    if (tickCount >= currentTriggerPoint[2] * ticksPerBrightnessStep) {
      faery_2_enable_due = false;
      fireFaerieSCR2();
      currentTriggerPoint[2] = nextTriggerPoint[2];
    }
  }

  if (triac_pulse_due) {
    // count the number of interrupts fired by the timer since the last zero cross
    if (tickCount >= currentTriggerPoint[0] * ticksPerBrightnessStep) {
      triac_pulse_due = false; // disable until the next zero cross

      if (lampOn) {
        fireTriac();
      }

      currentTriggerPoint[0] = nextTriggerPoint[0];
      sentTriacPulse = true;
    }
  }

#ifdef DEBUG_IN_TIMER_ISR
  PORTB &= ~_BV(dbgInTimerISR - PORT_B_BASE);
  // equivalent to... digitalWrite(dbgInTimerISR, LOW); // B10000
#endif
}

void zero_cross_detected()
{
#ifdef DEBUG_IN_ZERO_X_ISR
  PORTB |= _BV(dbgInZeroCrossISR - PORT_B_BASE);
#endif

  if (tickCount >= minimumTickCount) { // avoid glitches
    // zero cross is good, not a glitch
    tickCount = 0;

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

    delayMicroseconds(70);
  }

#ifdef DEBUG_IN_ZERO_X_ISR
  PORTB &= ~_BV(dbgInZeroCrossISR - PORT_B_BASE);
#endif
}
