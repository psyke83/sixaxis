# sixaxis

The sixaxis helper service is designed as a simple replacement for the sixad wrapper. It will
* install udev rules to suppress the motion sensors node (as it causes issues with player slot assignment in emulators)
* configure a sensible fuzz for analog axes (so that the analog sticks will not produce events when in a resting state)
* implement a simple 10 minute idle timeout mechanism (as the bluez plugin does not support the standard IdleTimeout timer).

The service is recommend for use with kernel 4.15 and Bluez 5.48 to ensure full compatibility with third-party controllers.
