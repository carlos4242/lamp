# lamp

I'm fairly horrified or pleased to realise I started this project nearly three years ago!

The [arduino sketch](https://github.com/carlos4242/lamp/blob/master/sketch_feb1st2015/sketch_feb1st2015.ino) runs a simple webserver and the suite of apps connect to it and in response to
switches being flipped, perform various web service calls.

It needs some cleanup and has the occasional bug.  Any contributions greatly appreciated!

See the [blog post](https://petosoft.wordpress.com/2015/05/03/homebrew-lights-in-my-flat-controlled-by-arduino-and-apple-watch/) for how I constructed the hardware.

Note that in the latest iteration of the hardware, I've changed the way the relays are soldered.  Now, when powered off, the relays connect the mains wire.  This might seem odd but was actually the best solution, which I stumbled upon by accident.  It means that if the arduino project fails or is powered down, the lights revert to being "normal".  They all still have switches on the cable that can be used to turn the lights off and on when the arduino is powered down.  As a result now when the web interface is read if it shows lamp1:1,lamp2:1,lamp3:1 that means all relays have power and all lamps are OFF.
I overhauled the sketch so it handles memory more efficiently (storing the favicon/html in flash instead of RAM) and remembers state in EEPROM when power cycled.  The API was overhauled to be more RESTful (doesn't give huge functional benefit but makes it more future proof and elegant) and a placeholder has been written for an HTML page/app to be served to clients that don't have the iOS app.  This will be able to use the same REST API to good effect in future.

Good luck!

Carl
