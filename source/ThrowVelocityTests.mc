import Toybox.Lang;

(:test)
function stationaryWristDoesNotStartThrow(logger) as Boolean {
    var view = new ThrowVelocityView();
    var positions = [[1000, 0, 0], [-1000, 0, 0], [0, 1000, 0],
        [0, -1000, 0], [0, 0, 1000], [0, 0, -1000]];
    for (var axis = 0; axis < positions.size(); axis += 1) {
        for (var i = 0; i < 10; i += 1) {
            view._processSample(positions[axis][0], positions[axis][1], positions[axis][2]);
        }
    }
    return !view._isThrowing && view._lastThrows.size() == 0;
}

(:test)
function swingUpdatesAndFinishesAtDifferentWristAngle(logger) as Boolean {
    var view = new ThrowVelocityView();
    for (var i = 0; i < 8; i += 1) {
        view._processSample(10000, 0, 0);
    }
    if (!view._isThrowing || view._getDisplayKmh() <= 0.0) {
        return false;
    }
    for (var i = 0; i < 5; i += 1) {
        view._processSample(0, -1000, 0);
    }
    return !view._isThrowing && view._lastThrows.size() == 1 &&
        view._getDisplayKmh() > 0.0 && view._maxThrowKmh > 0.0;
}

(:test)
function isolatedSpikeIsIgnored(logger) as Boolean {
    var view = new ThrowVelocityView();
    view._processSample(4000, 0, 0);
    for (var i = 0; i < 10; i += 1) {
        view._processSample(1000, 0, 0);
    }
    return !view._isThrowing && view._lastThrows.size() == 0;
}

(:test)
function continuousMotionHasTimeLimit(logger) as Boolean {
    var view = new ThrowVelocityView();
    for (var i = 0; i < 50; i += 1) {
        view._processSample(10000, 0, 0);
    }
    return !view._isThrowing && view._lastThrows.size() == 1;
}

(:test)
function repeatedSwingsKeepFiveResultsAndReset(logger) as Boolean {
    var view = new ThrowVelocityView();
    for (var swing = 0; swing < 7; swing += 1) {
        for (var i = 0; i < 8; i += 1) {
            view._processSample(10000 + swing * 1000, 0, 0);
        }
        for (var i = 0; i < 5; i += 1) {
            view._processSample(0, 0, -1000);
        }
    }
    if (view._lastThrows.size() != 5 || view._lastThrows[0] >= view._lastThrows[4]) {
        return false;
    }
    view.resetStats();
    return view._lastThrows.size() == 0 && view._getDisplayKmh() == 0.0 &&
        view._maxThrowKmh == 0.0 && !view._isThrowing;
}

(:test)
function publishedBaseModelReferenceValues(logger) as Boolean {
    var view = new ThrowVelocityView();
    // Independent reference values from the published rounded coefficients.
    return (view._estimateKmh(10.0) - 35.41156).abs() < 0.001 &&
        (view._estimateKmh(50.0) - 72.49301).abs() < 0.001 &&
        view._estimateKmh(0.0) == 0.0 && view._estimateKmh(-1.0) == 0.0 &&
        view._estimateKmh(1.0) == 0.0;
}

(:test)
function modelUsesTotalAccelerationInG(logger) as Boolean {
    var view = new ThrowVelocityView();
    for (var i = 0; i < 4; i += 1) {
        view._processSample(3000, 4000, 0);
    }
    // The 3-4-5 vector must remain 5 g, with gravity included.
    return (view._peakAccelerationG - 5.0).abs() < 0.001 &&
        (view._getDisplayKmh() - view._estimateKmh(5.0)).abs() < 0.001;
}

(:test)
function durationDoesNotInflatePeakPrediction(logger) as Boolean {
    var shortView = new ThrowVelocityView();
    var longView = new ThrowVelocityView();
    for (var i = 0; i < 5; i += 1) {
        shortView._processSample(10000, 0, 0);
    }
    for (var i = 0; i < 30; i += 1) {
        longView._processSample(10000, 0, 0);
    }
    return shortView._getDisplayKmh() > 0.0 &&
        (shortView._getDisplayKmh() - longView._getDisplayKmh()).abs() < 0.001;
}

(:test)
function peakBeforeStartConfirmationIsPreserved(logger) as Boolean {
    var view = new ThrowVelocityView();
    view._processSample(10000, 0, 0);
    view._processSample(4000, 0, 0);
    return view._isThrowing && (view._peakAccelerationG - 10.0).abs() < 0.001;
}

(:test)
function sampleRateChangesGateDurations(logger) as Boolean {
    var view = new ThrowVelocityView();
    view._configureSampleRate(100);
    for (var i = 0; i < 3; i += 1) {
        view._processSample(10000, 0, 0);
    }
    if (view._isThrowing) {
        return false;
    }
    view._processSample(10000, 0, 0);
    if (!view._isThrowing) {
        return false;
    }
    for (var i = 0; i < 11; i += 1) {
        view._processSample(0, 1000, 0);
    }
    if (!view._isThrowing) {
        return false;
    }
    view._processSample(0, 1000, 0);
    return !view._isThrowing && view._lastThrows.size() == 1;
}

(:test)
function timeoutRequiresRestBeforeAnotherThrow(logger) as Boolean {
    var view = new ThrowVelocityView();
    for (var i = 0; i < 150; i += 1) {
        view._processSample(10000, 0, 0);
    }
    return view._lastThrows.size() == 1 && !view._isThrowing;
}
