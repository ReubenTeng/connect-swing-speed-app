using Toybox.WatchUi;

class ThrowVelocityDelegate extends WatchUi.InputDelegate {

    function initialize() {
        InputDelegate.initialize();
    }

    function onSelect() as Boolean {
        var view = WatchUi.getCurrentView();
        if (view != null && view has :resetStats) {
            view.resetStats();
            return true;
        }

        return false;
    }
}
