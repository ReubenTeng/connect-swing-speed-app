using Toybox.Application;
using Toybox.WatchUi;

class ThrowVelocityApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new ThrowVelocityView();
        return [ view, new ThrowVelocityDelegate(view) ];
    }
}

function getApp() {
    return Application.getApp();
}
