using Toybox.WatchUi;
import Toybox.Lang;

class ThrowVelocityDelegate extends WatchUi.InputDelegate {

    var _view as ThrowVelocityView;

    function initialize(view as ThrowVelocityView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.resetStats();
        return true;
    }
}
