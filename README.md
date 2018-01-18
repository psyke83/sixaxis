# sixaxis

The sixaxis helper service is designed as a simple replacement for the sixad wrapper. It will
* automatically register detected USB devices as trusted in the Bluetooth stack
* configure a sensible fuzz for analog axes (needed on recent hid-sony driver) 
* implement a simple idle timeout mechanism for the native BlueZ sixaxis plugin (which does not respect the IdleTimeout setting)

The service is recommend for use with kernel 4.15 and Bluez 5.48 to ensure full compatibility with third-party controllers.
