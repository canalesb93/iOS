import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Reports the moment a finger lands and then fails straight away, so it never competes with the web view's
/// own gestures. Used to photograph the page just before a tap navigates away from it.
final class TouchDownGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let onTouchDown: () -> Void

    init(onTouchDown: @escaping () -> Void) {
        self.onTouchDown = onTouchDown
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if numberOfTouches <= 1 {
            onTouchDown()
        }
        state = .failed
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
