# Throw Velocity Connect IQ App

A Garmin Connect IQ activity app (Monkey C) that estimates throwing velocity from accelerometer data.

## Features

- Registers accelerometer sensor updates at 25 Hz.
- Converts acceleration from milli-G to m/s².
- Removes gravity bias from z-axis (+9.81 m/s² at rest).
- Computes net acceleration magnitude.
- Detects throw start/end using configurable thresholds and consecutive-sample gating.
- Integrates acceleration magnitude with trapezoidal rule to estimate final throw velocity.
- Shows throw result in km/h and mph.
- Stores and displays the latest 5 throws plus session max.
- Reset all stats with **SELECT**.

## Files

- `source/ThrowVelocityApp.mc` — app entry point.
- `source/ThrowVelocityView.mc` — sensor processing + UI rendering.
- `source/ThrowVelocityDelegate.mc` — SELECT button handling for reset.
- `manifest.xml` — app manifest targeting `fenix6` and `fr245`.
- `resources/strings.xml` — localized strings.

## Notes

- Sensor listener cleanup is done in `onStop()`.
- Sensor callback guards against null data before processing.
- Uses `Toybox.Math.sqrt()` and `System.getTimer()` per requirements.
