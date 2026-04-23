using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Sensor;
using Toybox.System;
using Toybox.WatchUi;

class ThrowVelocityView extends WatchUi.View {

    const SAMPLE_HZ = 25.0;
    const GRAVITY_MS2 = 9.81;
    const START_THRESHOLD_MS2 = 3.0;
    const END_THRESHOLD_MS2 = 1.5;
    const CONSECUTIVE_SAMPLES = 3;
    const RESET_MESSAGE_DURATION_MS = 1000;

    var _lastThrowKmh as Float = 0.0;
    var _lastThrowMph as Float = 0.0;
    var _maxThrowKmh as Float = 0.0;
    var _lastThrows as Array<Float> = [];

    var _isThrowing as Boolean = false;
    var _integratedVelocityMs as Float = 0.0;
    var _lastMagnitude as Float = 0.0;
    var _lastTimestampMs as Number? = null;

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
    }

    function onStop() as Void {
        Sensor.unregisterSensorDataListener();
    }

    function onUpdate(dc as Dc) as Void {
        _updateResetMessageState();

        dc.clear();
        var width = dc.getWidth();
        var height = dc.getHeight();

        if (_showResetMessage) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_MEDIUM, Rez.Strings.resetMessage, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var kmhText = Lang.format("$1$ km/h", [_formatOneDecimal(_lastThrowKmh)]);
        var mphText = Lang.format("$1$ mph", [_formatOneDecimal(_lastThrowMph)]);
        var maxText = Lang.format(Rez.Strings.maxLabel + " $1$ km/h", [_formatOneDecimal(_maxThrowKmh)]);

        dc.drawText(width / 2, height / 2 - 30, Graphics.FONT_NUMBER_THAI_HOT, kmhText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height / 2 + 20, Graphics.FONT_SMALL, mphText, Graphics.TEXT_JUSTIFY_CENTER);

        var y = height - 70;
        dc.drawText(width / 2, y, Graphics.FONT_XTINY, maxText, Graphics.TEXT_JUSTIFY_CENTER);

        var historyLabel = Rez.Strings.lastThrowsLabel + ": " + _formatHistory();
        dc.drawText(width / 2, height - 35, Graphics.FONT_XTINY, historyLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function resetStats() as Void {
        _lastThrowKmh = 0.0;
        _lastThrowMph = 0.0;
        _maxThrowKmh = 0.0;
        _lastThrows = [];

        _isThrowing = false;
        _integratedVelocityMs = 0.0;
        _lastMagnitude = 0.0;
        _lastTimestampMs = null;
        _startCount = 0;
        _endCount = 0;

        _showResetMessage = true;
        _resetMessageUntilMs = System.getTimer() + RESET_MESSAGE_DURATION_MS;
        WatchUi.requestUpdate();
    }

    function _startSensorListener() as Void {
        var options = {
            :period => 1.0 / SAMPLE_HZ
        };
        Sensor.registerSensorDataListener(method(:_onSensorData), options);
    }

    function _onSensorData(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo == null || sensorInfo.accelerometerData == null) {
            return;
        }

        var sample = sensorInfo.accelerometerData;
        if (sample.x == null || sample.y == null || sample.z == null) {
            return;
        }

        var nowMs = System.getTimer();

        var xMs2 = (sample.x / 1000.0) * GRAVITY_MS2;
        var yMs2 = (sample.y / 1000.0) * GRAVITY_MS2;
        var zMs2 = (sample.z / 1000.0) * GRAVITY_MS2;

        // Remove gravity bias from dominant z-axis.
        zMs2 = zMs2 - GRAVITY_MS2;

        var magnitude = Math.sqrt((xMs2 * xMs2) + (yMs2 * yMs2) + (zMs2 * zMs2));

        if (!_isThrowing) {
            if (magnitude > START_THRESHOLD_MS2) {
                _startCount += 1;
            } else {
                _startCount = 0;
            }

            if (_startCount >= CONSECUTIVE_SAMPLES) {
                _isThrowing = true;
                _integratedVelocityMs = 0.0;
                _lastMagnitude = magnitude;
                _lastTimestampMs = nowMs;
                _endCount = 0;
            }
            return;
        }

        if (_lastTimestampMs != null) {
            var dtSec = (nowMs - _lastTimestampMs) / 1000.0;
            if (dtSec > 0) {
                _integratedVelocityMs += ((_lastMagnitude + magnitude) / 2.0) * dtSec;
            }
        }

        _lastMagnitude = magnitude;
        _lastTimestampMs = nowMs;

        if (magnitude < END_THRESHOLD_MS2) {
            _endCount += 1;
        } else {
            _endCount = 0;
        }

        if (_endCount >= CONSECUTIVE_SAMPLES) {
            _finishThrow();
        }
    }

    function _finishThrow() as Void {
        _isThrowing = false;
        _startCount = 0;
        _endCount = 0;
        _lastTimestampMs = null;

        _lastThrowKmh = _integratedVelocityMs * 3.6;
        _lastThrowMph = _integratedVelocityMs * 2.236936;

        if (_lastThrowKmh > _maxThrowKmh) {
            _maxThrowKmh = _lastThrowKmh;
        }

        _lastThrows.add(_lastThrowKmh);
        while (_lastThrows.size() > 5) {
            _lastThrows.remove(0);
        }

        WatchUi.requestUpdate();
    }

    function _updateResetMessageState() as Void {
        if (_showResetMessage && System.getTimer() >= _resetMessageUntilMs) {
            _showResetMessage = false;
        }
    }

    function _formatOneDecimal(value as Float) as String {
        return Lang.format("%.1f", [value]);
    }

    function _formatHistory() as String {
        if (_lastThrows.size() == 0) {
            return "-";
        }

        var output = "";
        for (var i = 0; i < _lastThrows.size(); i += 1) {
            output += _formatOneDecimal(_lastThrows[i]);
            if (i < _lastThrows.size() - 1) {
                output += ", ";
            }
        }
        return output;
    }
}
