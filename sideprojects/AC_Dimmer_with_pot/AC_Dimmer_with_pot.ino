/*
 AC_Dimmer_with_pot
 
 This sketch is a sample sketch using the ZeroCross Tail(ZCT) to generate a sync
 pulse to drive a PowerSSR Tail(PSSRT) for dimming ac lights.
 
 Download TimerOne.h from the Arduino library and place in the folder applicable
 to your operating system.
 
 Connection to an Arduino Duemilanove:
 1. Connect the C terminal of the ZeroCross Tail to digital pin 2 with a 10K ohm pull up to 5V.
 2. Connect the E terminal of the ZeroCross Tail to GND.
 3. Connect the center terminal of a 10K ohm potentiometer to ADC0. Also connnect the CW 
 terminal to 5V and the CCW terminal to GND.
 4. Connect the PowerSSR Tail +in terminal to Digital pin 4 and the -in terminal to GND.
 
 
*/


#include <TimerOne.h>

volatile int i=0;               // Variable to use as a counter
volatile boolean zero_cross=0;  // Boolean to store a "switch" to tell us if we have 
                                // crossed zero
int PSSR1 = 4;                  // PSSRT connected to digital pin 4
int dim = 32;                   // Default Dimming level (0-128)  0 = on, 128 = off if 
                                // unable to find pot
int freqStep = 73;              // Adjust this value for full off PSSRT when pot
                                // is fully CCW; you may have flicker at max CW end
int pot = 0;                    // External potentiometer connected to analog input pin 0
int LED = 0;                    // Arduino board LED on digital pin 13

void setup()
{
 pinMode(LED, OUTPUT);
 pinMode(4, OUTPUT);                              // Set PSSR1 pin as output
 attachInterrupt(0, zero_cross_detect, RISING);   // Attach an Interupt to Pin 2 
                                                 // (interupt 0) for Zero Cross Detection
 Timer1.initialize(freqStep);
 Timer1.attachInterrupt(dim_check,freqStep);
}

void dim_check() {                  // This function will fire the triac at the 
                                    // proper time
 if(zero_cross == 1) {              // First check to make sure the zero-cross has 
                                    //happened else do nothing
   if(i>=dim) {
    delayMicroseconds(100);        //These values will fire the PSSR Tail.
    digitalWrite(PSSR1, HIGH);
    delayMicroseconds(50);
    digitalWrite(PSSR1, LOW); 
     i = 0;                         // Reset the accumulator
     zero_cross = 0;                // Reset the zero_cross so it may be turned on 
                                   // again at the next zero_cross_detect    
   } else {
     i++;                           // If the dimming value has not been reached, 
                                   // increment the counter
   }                                // End dim check
 }                                  // End zero_cross check
}

void zero_cross_detect() 
{
   zero_cross = 1;
   // set the boolean to true to tell our dimming function that a zero cross has occured
} 

void loop()                        // Main loop
{
  dim = analogRead(pot)/10;         // Read the pot value
}



