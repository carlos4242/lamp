void fireTriac() {
  digitalWrite(PSSR1, HIGH);
  delayMicroseconds(500);
  digitalWrite(PSSR1, LOW);
}

// ISRs
// All these functions are ISRs, be wary of volatile variables, side effects and speed

// Timer tick function.
// This function will wait for zero cross, then after that, increment a counter on each tick until the proper time,
// then finally fire the triac, reset the zero_cross flag and counter, ready for the next zero cross.

volatile boolean zero_cross = false; // Boolean to store a "switch" to tell us if we have crossed zero
volatile static int i = 0; // count the number of interrupts fired by the timer since the last zero cross

void timer_tick_function() {
  if (!zero_cross) return; // waiting for zero cross

  if (i < currentTriggerPoint * brightnessMultiplier) {
    i++;
  } else {
    zero_cross = false; // disable until the next zero cross
    if (lampOn) {
      fireTriac();
    }
    sentPulse = true;
  }
}

void zero_cross_detect()
{
  i = 0;
  zero_cross = true;
  sentPulse = false; // prevent main loop action from occurring until after next zero cross cycle is complete
}
