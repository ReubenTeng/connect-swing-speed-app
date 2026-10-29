# Throw Velocity Connect IQ App

## Problem
As a casual dodgeball player, I want to know if my throw speed is increasing based on form. However, I don't have access to a radar gun consistently. I do however own a Garmin watch, which has an accelerometer.

## Solution

A Garmin Connect IQ activity app (Monkey C) that estimates throwing velocity from accelerometer data.

## Features

- Requests the highest accelerometer sample rate reported by the watch. Falls back to 25 Hz if registration fails.
- Converts acceleration from millig to g.
- Detects rest from acceleration vector length, independent of wrist orientation.
- Detects throw start/end using configurable thresholds and consecutive-sample gating.
- Uses the published handball Base model: peak total acceleration and a natural logarithm.
- Shows the current estimate during movement and the last result in km/h and mph.
- Ends a measurement after a return to rest or a two-second limit.
- Marks the output as experimental. Also shows sensor waiting, measuring, and error states.
- Stores and displays the latest 5 throws plus session max.
- Reset all stats with **SELECT**.

## Files

- `source/ThrowVelocityApp.mc` — app entry point.
- `source/ThrowVelocityView.mc` — sensor processing + UI rendering.
- `source/ThrowVelocityDelegate.mc` — SELECT button handling for reset.
- `manifest.xml` — app manifest targeting `fenix6`, `fr245`, and `fr265`.
- `resources/strings.xml` — localized strings.

## Notes

- Sensor listener cleanup is done in `onHide()`.
- Sensor samples arrive in one-second batches. Display updates can lag movement by about one second.
- Speed is an uncalibrated estimate from wrist motion. It is not a validated measurement of ball or club speed.
- Sensor callback guards against null data before processing.
- Uses `Toybox.Math.sqrt()` and `System.getTimer()` per requirements.

## Experimental handball Base model

Source: Skejo et al., *Estimating Throwing Speed in Handball Using a Wearable Device*, Sensors 2020, 20(17), 4925. DOI: https://doi.org/10.3390/s20174925

The model uses Table 3's rounded Base coefficients:

```text
peak_g = max(sqrt(x_g^2 + y_g^2 + z_g^2)) over one throw
speed_m_s = -4.9 + 6.4 * ln(peak_g)
speed_km_h = speed_m_s * 3.6
```

Gravity stays in the model input. Subtracting 1 g changes the predictor used in the study. Negative predictions are rejected. The Base model needs no sex or throw-type setting. The authors' public analysis uses R's natural `log(Acceleration)`. Their [data dictionary](https://osf.io/y8vgb) specifies acceleration in g. The [analysis code](https://osf.io/d4k9v) is available with the study.

The study used a custom sensor at about 500 Hz with a +/-200 g range. The Garmin's actual rate is reported in the debug log. This app cannot establish the Garmin sensor's acceleration range or detect all forms of sensor saturation. Missed or clipped peaks can change predictions. A higher sampling rate alone cannot establish accuracy.

The authors manually selected segments containing one throw. This app uses automatic movement gates. That segmentation is an adaptation and was not validated by the study. Keep throws separate and stop moving between throws. The two-second limit requires a return to rest before another measurement.

The published accuracy applies to the study's handball measurements. It does not establish accuracy for Garmin watches, dodgeball, sidearm throws, or this app. No correction has been fitted to the user's reported reference speed. Compare paired watch and reference measurements before using these estimates as ball speed.

Regression tests check the equation, g units, total acceleration, duration independence, peak preservation, sample-rate gates, rest orientation, isolated spikes, timeout behavior, history, and reset. These tests verify software behavior, not physical measurement accuracy.
