import Shared
import UIKit

// MARK: - Gesture Setup & Handling

extension WebViewController {
    func setupGestures(numberOfTouchesRequired: Int) {
        let gestures = [.left, .right, .up, .down].map { (direction: UISwipeGestureRecognizer.Direction) in
            let gesture = UISwipeGestureRecognizer()
            gesture.numberOfTouchesRequired = numberOfTouchesRequired
            gesture.direction = direction
            gesture.addTarget(self, action: #selector(swipe(_:)))
            gesture.delegate = self
            return gesture
        }

        for gesture in gestures {
            view.addGestureRecognizer(gesture)
        }
    }

    func setupEdgeGestures() {
        webView.addGestureRecognizer(leftEdgePanGestureRecognizer)
        webView.addGestureRecognizer(rightEdgeGestureRecognizer)
    }

    @objc func swipe(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        let action = Current.settingsStore.gestures.getAction(for: gesture, numberOfTouches: gesture.numberOfTouches)
        webViewGestureHandler.handleGestureAction(action)
    }

    @objc func screenEdgeGestureRecognizerAction(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.edges == .left, let nativeSidebarEdgePanHandler,
           (Current.settingsStore.gestures[.swipeRight] ?? .none) == .showSidebar {
            nativeSidebarEdgePanHandler(gesture)
            return
        }
        guard gesture.state == .ended else {
            return
        }
        let gesture: AppGesture = gesture.edges == .left ? .swipeRight : .swipeLeft
        let action = Current.settingsStore.gestures[gesture] ?? .none
        webViewGestureHandler.handleGestureAction(action)
    }
}

// MARK: - Native sidebar edge navigation

extension WebViewController {
    /// Splits the left edge between the drawer and going back: at the top of a panel the edge belongs to the
    /// drawer, below it WebKit's own interactive back swipe takes over, with its page snapshot sliding
    /// under the finger like Safari.
    func updateNativeSidebarEdgeNavigation(isAtPanelRoot: Bool, isEnabled: Bool) {
        guard isViewLoaded, let webView else { return }
        let usesBackSwipe = isEnabled && !isAtPanelRoot && webView.canGoBack
        if webView.allowsBackForwardNavigationGestures != usesBackSwipe {
            webView.allowsBackForwardNavigationGestures = usesBackSwipe
        }
        leftEdgePanGestureRecognizer.isEnabled = !usesBackSwipe
    }
}
