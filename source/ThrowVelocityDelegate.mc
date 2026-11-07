using Toybox.WatchUi;
import Toybox.Lang;

class ThrowVelocityDelegate extends WatchUi.BehaviorDelegate {

    var _view as ThrowVelocityView;

    function initialize(view as ThrowVelocityView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.resetStats();
        return true;
    }
}
