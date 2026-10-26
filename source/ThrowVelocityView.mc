import Toybox.Graphics;
import Toybox.Lang;
using Toybox.Math;
using Toybox.Sensor;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class ThrowVelocityView extends WatchUi.View {

    const DEFAULT_SAMPLE_HZ = 25;
    // Skejo et al. (2020), Table 3, Base model. Acceleration is in g.
    // https://doi.org/10.3390/s20174925
    const BASE_INTERCEPT_MS = -4.9;
    const BASE_LOG_PEAK_COEFFICIENT = 6.4;
    const GRAVITY_MS2 = 9.81;
    const START_THRESHOLD_MS2 = 3.0;
    const END_THRESHOLD_MS2 = 1.5;
    var _sampleRateHz as Number = DEFAULT_SAMPLE_HZ;
    var _startSamples as Number = 2;
    var _endSamples as Number = 3;
    var _maxThrowSamples as Number = DEFAULT_SAMPLE_HZ * 2;
    const SENSOR_TIMEOUT_MS = 4000;
    const RESET_MESSAGE_DURATION_MS = 1000;

    var _lastThrowKmh as Float = 0.0;
    var _lastThrowMph as Float = 0.0;
    var _maxThrowKmh as Float = 0.0;
    var _lastThrows as Array<Float> = [];

    var _isThrowing as Boolean = false;
    var _peakAccelerationG as Float = 0.0;
    var _candidatePeakG as Float = 0.0;
    var _throwSampleCount as Number = 0;
    var _waitingForRest as Boolean = false;
    var _lastSensorUpdateMs as Number? = null;
    var _sensorError as Boolean = false;
    var _refreshTimer as Timer.Timer = new Timer.Timer();

    var _startCount as Number = 0;
    var _endCount as Number = 0;

    var _showResetMessage as Boolean = false;
    var _resetMessageUntilMs as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        _startSensorListener();
        _refreshTimer.start(method(:_refresh), 1000, true);
    }

    function onHide() as Void {
        _refreshTimer.stop();
        Sensor.unregisterSensorDataListener();
        _resetDetection();
    }

    function _refresh() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        _updateResetMessageState();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var width = dc.getWidth();
        var height = dc.getHeight();

        var centerX = width / 2;
        var accent = 0xA8EF4D;
        var muted = 0x999999;
        var centered = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var status = "EXPERIMENTAL";
        if (_sensorError) {
            status = "SENSOR ERROR";
        } else if (_lastSensorUpdateMs == null) {
            status = "WAITING";
        } else if (System.getTimer() - _lastSensorUpdateMs > SENSOR_TIMEOUT_MS) {
            status = "NO SENSOR DATA";
        } else if (_showResetMessage) {
            status = "RESET";
        } else if (_isThrowing) {
            status = "MEASURING";
        }

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        _drawSmallText(dc, status, centerX, height * 0.16, width * 0.68);

        // Keep only the number in the large font. Fit it before drawing.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var displayKmh = _getDisplayKmh();
        _drawSpeed(dc, _formatOneDecimal(displayKmh), centerX, height * 0.35,
            width * 0.74, height * 0.26);

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.50, Graphics.FONT_SMALL, "km/h EST.", centered);
        dc.setColor(muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.59, Graphics.FONT_XTINY,
            _formatOneDecimal(displayKmh / 1.609344) + " mph", centered);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(width * 0.23, height * 0.66, width * 0.77, height * 0.66);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var maxText = "MAX  " + _formatOneDecimal(_maxThrowKmh) + " km/h";
        _drawSmallText(dc, maxText, centerX, height * 0.73, width * 0.72);

        dc.setColor(muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 0.80, Graphics.FONT_XTINY, "LAST 5  /  km/h", centered);
        var firstEnd = _lastThrows.size();
        if (firstEnd > 3) {
            firstEnd = 3;
        }
        _drawSmallText(dc, _formatHistory(0, firstEnd), centerX,
            height * 0.86, width * 0.60);
        if (_lastThrows.size() > 3) {
            _drawSmallText(dc, _formatHistory(3, _lastThrows.size()), centerX,
                height * 0.92, width * 0.40);
        }
    }

    function _drawSpeed(dc as Dc, text as String, x, y, maxWidth, maxHeight) as Void {
        var fonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL,
            Graphics.FONT_XTINY];
        var font = Graphics.FONT_XTINY;
        for (var i = 0; i < fonts.size(); i += 1) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth &&
                dc.getFontHeight(fonts[i]) <= maxHeight) {
                font = fonts[i];
                break;
            }
        }
        dc.drawText(x, y, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawSmallText(dc as Dc, text as String, x, y, maxWidth) as Void {
        var font = Graphics.FONT_XTINY;
        var fitted = text;
        var length = text.length();
        while (dc.getTextWidthInPixels(fitted, font) > maxWidth && length > 0) {
            length -= 1;
            fitted = text.substring(0, length) + "...";
        }
        dc.drawText(x, y, font, fitted,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function resetStats() as Void {
        _lastThrowKmh = 0.0;
        _lastThrowMph = 0.0;
        _maxThrowKmh = 0.0;
        _lastThrows = [];

        _resetDetection();

        _showResetMessage = true;
        _resetMessageUntilMs = System.getTimer() + RESET_MESSAGE_DURATION_MS;
        WatchUi.requestUpdate();
    }

    function _startSensorListener() as Void {
        _lastSensorUpdateMs = null;
        _sensorError = false;
        _resetDetection();
        try {
            _configureSampleRate(Sensor.getMaxSampleRate());
            _registerAccelerometer();
        } catch (error) {
            // Some firmware reports rates that registration will not accept.
            try {
                _configureSampleRate(DEFAULT_SAMPLE_HZ);
                _registerAccelerometer();
            } catch (fallbackError) {
                _sensorError = true;
                System.println("Accelerometer registration failed: " + fallbackError.getErrorMessage());
            }
        }
    }

    function _configureSampleRate(rate as Number) as Void {
        _sampleRateHz = rate > 0 ? rate : DEFAULT_SAMPLE_HZ;
        // Gates represent durations, so a higher rate does not shorten them.
        _startSamples = (_sampleRateHz * 0.04).toNumber();
        if (_startSamples < 2) {
            _startSamples = 2;
        }
        _endSamples = (_sampleRateHz * 0.12).toNumber();
        if (_endSamples < 1) {
            _endSamples = 1;
        }
        _maxThrowSamples = _sampleRateHz * 2;
    }

    function _registerAccelerometer() as Void {
        Sensor.registerSensorDataListener(method(:_onSensorData), {
            :period => 1,
            :accelerometer => {
                :enabled => true,
                :sampleRate => _sampleRateHz
            }
        });
        System.println("Base model accelerometer rate: " + _sampleRateHz + " Hz");
    }

    function _onSensorData(sensorInfo as Sensor.SensorData) as Void {
        var sample = sensorInfo.accelerometerData;
        if (sample == null || sample.x.size() == 0) {
            return;
        }
        _lastSensorUpdateMs = System.getTimer();
        _sensorError = false;

        for (var i = 0; i < sample.x.size(); i += 1) {
            _processSample(sample.x[i], sample.y[i], sample.z[i]);
        }

        // Sensor callbacks also refresh the reset message after its timeout.
        WatchUi.requestUpdate();
    }

    function _processSample(x as Number, y as Number, z as Number) as Void {
        // Convert Garmin millig to g before squaring to avoid integer overflow.
        var xG = x / 1000.0;
        var yG = y / 1000.0;
        var zG = z / 1000.0;
        var totalG = Math.sqrt(xG * xG + yG * yG + zG * zG);
        // Gravity is used only for segmentation, never removed from model input.
        var movementMs2 = (totalG - 1.0).abs() * GRAVITY_MS2;

        if (_waitingForRest) {
            if (movementMs2 < END_THRESHOLD_MS2) {
                _endCount += 1;
                if (_endCount >= _endSamples) {
                    _waitingForRest = false;
                    _endCount = 0;
                }
            } else {
                _endCount = 0;
            }
            return;
        }

        if (!_isThrowing) {
            if (movementMs2 > START_THRESHOLD_MS2) {
                _startCount += 1;
                if (totalG > _candidatePeakG) {
                    _candidatePeakG = totalG;
                }
            } else {
                _startCount = 0;
                _candidatePeakG = 0.0;
            }
            if (_startCount >= _startSamples) {
                _isThrowing = true;
                _peakAccelerationG = _candidatePeakG;
                _throwSampleCount = _startCount;
                _endCount = 0;
            }
            return;
        }

        if (totalG > _peakAccelerationG) {
            _peakAccelerationG = totalG;
        }
        _throwSampleCount += 1;
        if (movementMs2 < END_THRESHOLD_MS2) {
            _endCount += 1;
        } else {
            _endCount = 0;
        }

        if (_endCount >= _endSamples) {
            _finishThrow();
        } else if (_throwSampleCount >= _maxThrowSamples) {
            _finishThrow();
            _waitingForRest = true;
        }
    }

    function _estimateKmh(peakG as Float) as Float {
        if (peakG <= 0.0) {
            return 0.0;
        }
        // R's log() is the natural logarithm; use base e in Monkey C.
        var speedMs = BASE_INTERCEPT_MS + BASE_LOG_PEAK_COEFFICIENT * Math.log(peakG, 2.718281828);
        // The regression can predict negative speeds outside its training range.
        return speedMs > 0.0 ? speedMs * 3.6 : 0.0;
    }

    function _finishThrow() as Void {
        var peakG = _peakAccelerationG;
        var resultKmh = _estimateKmh(peakG);
        _resetDetection();
        if (resultKmh <= 0.0) {
            return;
        }
        _lastThrowKmh = resultKmh;
        _lastThrowMph = resultKmh / 1.609344;
        if (_lastThrowKmh > _maxThrowKmh) {
            _maxThrowKmh = _lastThrowKmh;
        }
        _lastThrows.add(_lastThrowKmh);
        while (_lastThrows.size() > 5) {
            _lastThrows = _lastThrows.slice(1, _lastThrows.size());
        }
        System.println("Base model result: peak=" + peakG + " g, rate=" +
            _sampleRateHz + " Hz, estimate=" + resultKmh + " km/h");
        WatchUi.requestUpdate();
    }

    function _resetDetection() as Void {
        _isThrowing = false;
        _peakAccelerationG = 0.0;
        _candidatePeakG = 0.0;
        _throwSampleCount = 0;
        _startCount = 0;
        _endCount = 0;
        _waitingForRest = false;
    }

    function _getDisplayKmh() as Float {
        return _isThrowing ? _estimateKmh(_peakAccelerationG) : _lastThrowKmh;
    }

    function _updateResetMessageState() as Void {
        if (_showResetMessage && System.getTimer() >= _resetMessageUntilMs) {
            _showResetMessage = false;
        }
    }

    function _formatOneDecimal(value as Float) as String {
        return value.format("%.1f");
    }

    function _formatHistory(start as Number, end as Number) as String {
        if (_lastThrows.size() == 0) {
            return "-";
        }

        var output = "";
        for (var i = start; i < end; i += 1) {
            output += _lastThrows[i].format("%.0f");
            if (i < end - 1) {
                output += "  ";
            }
        }
        return output;
    }
}
