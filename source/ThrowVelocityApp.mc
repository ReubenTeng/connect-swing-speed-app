using Toybox.Application;
using Toybox.WatchUi;

class ThrowVelocityApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new ThrowVelocityView(), new ThrowVelocityDelegate() ];
    }
}

function getApp() {
    return Application.getApp();
}
