import Shared
import UIKit
import WebKit

/// Gives the frontend's page-to-page navigation the motion of a navigation stack.
///
/// The frontend is a single live web view, so there is nothing to slide between: instead the controller
/// photographs each page as the user leaves it and composes transitions out of those photographs and the
/// live view.
/// - Push (drilling into a sub-page): the new page slides in from the trailing edge over the previous one,
///   which recedes with a parallax lag and dims.
/// - Pop (the frontend's back arrow): the page that was left slides off, uncovering the live page beneath.
/// - Interactive pop (left edge on a sub-page): the live page follows the finger, uncovering the previous
///   page's photograph; releasing past the threshold (or flicking) commits and only then navigates back.
@MainActor
final class FrontendPageTransitionController {
    private enum Constants {
        static let parallax: CGFloat = 0.3
        static let dimming: CGFloat = 0.12
        static let duration: TimeInterval = 0.5
        static let dampingRatio: CGFloat = 0.94
        static let commitVelocity: CGFloat = 500
        static let shadowOpacity: Float = 0.22
        static let shadowRadius: CGFloat = 14
        /// The photograph of the page coming back stays over the live view until it has had time to paint.
        static let revealDelay: TimeInterval = 0.12
        static let revealDuration: TimeInterval = 0.18
        static let maximumSnapshots = 8
    }

    private struct InteractivePop {
        let underlay: UIView
        let dimming: UIView
        let width: CGFloat
        var awaitingRoute = false
    }

    /// Off outside the sidebar navigation style and while the frontend's more-info dialog is up.
    var isEnabled = false

    private weak var webView: WKWebView?
    private weak var container: UIView?
    private var history = FrontendRouteHistory()
    private var snapshots: [String: UIImage] = [:]
    private var interactivePop: InteractivePop?
    private var animator: UIViewPropertyAnimator?
    private var transientViews: [UIView] = []
    private var settleSnapshotWorkItem: DispatchWorkItem?
    private var lastPushDate: Date?
    private var replaceExpiryWorkItem: DispatchWorkItem?

    init(webView: WKWebView, container: UIView) {
        self.webView = webView
        self.container = container
        webView.addGestureRecognizer(TouchDownGestureRecognizer { [weak self] in
            self?.captureSnapshot()
        })
    }

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    var canInteractivelyPop: Bool {
        isEnabled && history.canPop && interactivePop == nil && !NativeSidebarRoute.isRoot(history.current)
    }

    var isTrackingInteractivePop: Bool {
        interactivePop != nil
    }

    /// The sidebar is about to switch panels with `replace: true`: hold a picture of the outgoing panel over the
    /// live view and dissolve it once the new one is in, instead of letting the page swap in one frame.
    func expectReplace() {
        beginPanelCrossfade()
        history.expectsReplace = true
        replaceExpiryWorkItem?.cancel()
        // Re-selecting the panel already on screen never reports a change; don't let the flag outlive it.
        let workItem = DispatchWorkItem { [weak self] in self?.history.expectsReplace = false }
        replaceExpiryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    func routeDidChange(to path: String) {
        let isRedirect = lastPushDate.map { Date().timeIntervalSince($0) < 0.4 } ?? false
        let change = history.update(to: path, isRedirect: isRedirect)
        lastPushDate = { if case .push = change { return Date() } else { return nil } }()
        switch change {
        case let .push(from):
            if isEnabled, interactivePop == nil, let image = snapshots[from] {
                animatePush(over: image)
            }
        case let .pop(from):
            if interactivePop?.awaitingRoute == true {
                finishInteractivePop()
            } else if isEnabled, interactivePop == nil, let image = snapshots[from] {
                animatePop(leaving: image)
            }
        case .reset:
            finishInteractivePop()
            finishPanelCrossfade()
        case .none:
            break
        }
        if change != .none {
            pruneSnapshots()
            scheduleSettledSnapshot()
        }
    }

    // MARK: - Panel switches

    private var panelCrossfadeView: UIView?

    private func beginPanelCrossfade() {
        guard isEnabled, !reduceMotion, interactivePop == nil, let webView, let container,
              panelCrossfadeView == nil,
              let snapshot = webView.snapshotView(afterScreenUpdates: false) else { return }
        finishRunningAnimation()
        snapshot.frame = untransformedFrame(of: webView)
        snapshot.isUserInteractionEnabled = false
        container.insertSubview(snapshot, aboveSubview: webView)
        panelCrossfadeView = snapshot
        // Re-selecting the panel on screen never reports a route change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak snapshot] in
            guard let snapshot, self?.panelCrossfadeView === snapshot else { return }
            self?.finishPanelCrossfade()
        }
    }

    private func finishPanelCrossfade() {
        guard let view = panelCrossfadeView else { return }
        panelCrossfadeView = nil
        UIView.animate(
            withDuration: 0.28,
            delay: 0.1,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: { view.alpha = 0 },
            completion: { _ in view.removeFromSuperview() }
        )
    }

    // MARK: - Snapshots

    private func captureSnapshot() {
        guard let webView, let path = history.current, webView.bounds.width > 0, animator == nil else { return }
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = false
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let self, let image, history.current == path else { return }
            snapshots[path] = image
        }
    }

    /// A page reached without a tap (a link from a notification, the frontend redirecting) still needs a
    /// photograph for when the user later leaves it.
    private func scheduleSettledSnapshot() {
        settleSnapshotWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.captureSnapshot() }
        settleSnapshotWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    private func pruneSnapshots() {
        let keep = Set(history.stack)
        snapshots = snapshots.filter { keep.contains($0.key) }
        if snapshots.count > Constants.maximumSnapshots, let oldest = history.stack.first {
            snapshots[oldest] = nil
        }
    }

    // MARK: - Push / pop

    private func animatePush(over previous: UIImage) {
        guard let webView, let container, !reduceMotion else { return }
        finishRunningAnimation()
        let frame = untransformedFrame(of: webView)
        let width = frame.width

        let underlay = makeSnapshotView(previous, frame: frame)
        let dimming = makeDimmingView(frame: underlay.bounds, alpha: 0)
        underlay.addSubview(dimming)
        container.insertSubview(underlay, belowSubview: webView)
        transientViews = [underlay]

        setEdgeShadow(on: webView, frame: frame, visible: true)
        webView.transform = CGAffineTransform(translationX: width, y: 0)

        let animator = makeAnimator(initialVelocity: 0)
        animator.addAnimations {
            webView.transform = .identity
            underlay.transform = CGAffineTransform(translationX: -width * Constants.parallax, y: 0)
            dimming.alpha = Constants.dimming
        }
        animator.addCompletion { [weak self] _ in
            self?.cleanUp()
        }
        self.animator = animator
        animator.startAnimation()
    }

    private func animatePop(leaving page: UIImage) {
        guard let webView, let container, !reduceMotion else { return }
        finishRunningAnimation()
        let frame = untransformedFrame(of: webView)
        let width = frame.width

        let dimming = makeDimmingView(frame: frame, alpha: Constants.dimming)
        let leaving = makeSnapshotView(page, frame: frame)
        setEdgeShadow(on: leaving, frame: leaving.bounds, visible: true)
        container.insertSubview(dimming, aboveSubview: webView)
        container.insertSubview(leaving, aboveSubview: dimming)
        transientViews = [dimming, leaving]
        webView.transform = CGAffineTransform(translationX: -width * Constants.parallax, y: 0)

        let animator = makeAnimator(initialVelocity: 0)
        animator.addAnimations {
            leaving.transform = CGAffineTransform(translationX: width, y: 0)
            webView.transform = .identity
            dimming.alpha = 0
        }
        animator.addCompletion { [weak self] _ in
            self?.cleanUp()
        }
        self.animator = animator
        animator.startAnimation()
    }

    // MARK: - Interactive pop

    func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginInteractivePop()
        case .changed:
            updateInteractivePop(translation: gesture.translation(in: container).x)
        case .ended:
            endInteractivePop(
                translation: gesture.translation(in: container).x,
                velocity: gesture.velocity(in: container).x
            )
        case .cancelled, .failed:
            endInteractivePop(translation: 0, velocity: -1)
        default:
            break
        }
    }

    private func beginInteractivePop() {
        guard let webView, let container, canInteractivelyPop else { return }
        finishRunningAnimation()
        let frame = untransformedFrame(of: webView)

        let underlay: UIView
        if let previous = history.previous, let image = snapshots[previous] {
            underlay = makeSnapshotView(image, frame: frame)
        } else {
            underlay = UIView(frame: frame)
            underlay.backgroundColor = webView.underPageBackgroundColor
        }
        let dimming = makeDimmingView(frame: underlay.bounds, alpha: Constants.dimming)
        underlay.addSubview(dimming)
        underlay.transform = CGAffineTransform(translationX: -frame.width * Constants.parallax, y: 0)
        container.insertSubview(underlay, belowSubview: webView)
        setEdgeShadow(on: webView, frame: frame, visible: true)
        transientViews = [underlay]
        interactivePop = InteractivePop(underlay: underlay, dimming: dimming, width: frame.width)
    }

    private func updateInteractivePop(translation: CGFloat) {
        guard let webView, let pop = interactivePop, !pop.awaitingRoute else { return }
        let offset = max(0, translation)
        let progress = min(1, offset / max(pop.width, 1))
        webView.transform = CGAffineTransform(translationX: offset, y: 0)
        pop.underlay.transform = CGAffineTransform(translationX: -pop.width * Constants.parallax * (1 - progress), y: 0)
        pop.dimming.alpha = Constants.dimming * (1 - progress)
    }

    private func endInteractivePop(translation: CGFloat, velocity: CGFloat) {
        guard let webView, let pop = interactivePop, !pop.awaitingRoute else { return }
        let progress = max(0, translation) / max(pop.width, 1)
        let commits = velocity > Constants.commitVelocity || (progress > 0.5 && velocity > -Constants.commitVelocity)
        let remaining = commits ? pop.width - max(0, translation) : max(0, translation)
        let relativeVelocity = remaining > 1 ? abs(velocity) / remaining : 0

        let animator = makeAnimator(initialVelocity: min(relativeVelocity, 8))
        animator.addAnimations {
            if commits {
                webView.transform = CGAffineTransform(translationX: pop.width, y: 0)
                pop.underlay.transform = .identity
                pop.dimming.alpha = 0
            } else {
                webView.transform = .identity
                pop.underlay.transform = CGAffineTransform(translationX: -pop.width * Constants.parallax, y: 0)
                pop.dimming.alpha = Constants.dimming
            }
        }
        animator.addCompletion { [weak self] _ in
            guard let self else { return }
            self.animator = nil
            if commits {
                commitInteractivePop()
            } else {
                interactivePop = nil
                cleanUp()
            }
        }
        self.animator = animator
        animator.startAnimation()
    }

    /// The live view is off screen with the previous page's photograph where it belongs: put the photograph
    /// on top, bring the view home behind it, and only then navigate back, so the swap is invisible.
    private func commitInteractivePop() {
        guard let webView, let container, var pop = interactivePop else { return }
        container.insertSubview(pop.underlay, aboveSubview: webView)
        setEdgeShadow(on: webView, frame: webView.bounds, visible: false)
        webView.transform = .identity
        pop.awaitingRoute = true
        interactivePop = pop
        webView.goBack()
        // A frontend that refuses to go back (an unsaved-changes prompt) never reports the route.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard self?.interactivePop?.awaitingRoute == true else { return }
            self?.finishInteractivePop()
        }
    }

    private func finishInteractivePop() {
        guard let pop = interactivePop else { return }
        interactivePop = nil
        let underlay = pop.underlay
        UIView.animate(
            withDuration: Constants.revealDuration,
            delay: Constants.revealDelay,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: { underlay.alpha = 0 },
            completion: { [weak self] _ in self?.cleanUp() }
        )
    }

    // MARK: - Helpers

    private func makeAnimator(initialVelocity: CGFloat) -> UIViewPropertyAnimator {
        let timing = UISpringTimingParameters(
            dampingRatio: Constants.dampingRatio,
            initialVelocity: CGVector(dx: initialVelocity, dy: 0)
        )
        let animator = UIViewPropertyAnimator(duration: Constants.duration, timingParameters: timing)
        animator.isUserInteractionEnabled = true
        return animator
    }

    private func finishRunningAnimation() {
        if let animator, animator.state == .active {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .end)
        }
        animator = nil
        cleanUp()
    }

    private func cleanUp() {
        guard interactivePop == nil else { return }
        animator = nil
        transientViews.forEach { $0.removeFromSuperview() }
        transientViews = []
        if let webView {
            webView.transform = .identity
            setEdgeShadow(on: webView, frame: webView.bounds, visible: false)
        }
    }

    private func untransformedFrame(of view: UIView) -> CGRect {
        CGRect(
            x: view.center.x - view.bounds.width / 2,
            y: view.center.y - view.bounds.height / 2,
            width: view.bounds.width,
            height: view.bounds.height
        )
    }

    private func makeSnapshotView(_ image: UIImage, frame: CGRect) -> UIImageView {
        let view = UIImageView(image: image)
        view.frame = frame
        view.contentMode = .top
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }

    private func makeDimmingView(frame: CGRect, alpha: CGFloat) -> UIView {
        let view = UIView(frame: frame)
        view.backgroundColor = .black
        view.alpha = alpha
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }

    /// The shadow the leading edge of a sliding page casts on the page beneath, as a navigation stack draws it.
    private func setEdgeShadow(on view: UIView, frame: CGRect, visible: Bool) {
        view.layer.shadowOpacity = visible ? Constants.shadowOpacity : 0
        guard visible else { return }
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = Constants.shadowRadius
        view.layer.shadowOffset = CGSize(width: -2, height: 0)
        view.layer.shadowPath = UIBezierPath(rect: CGRect(origin: .zero, size: frame.size)).cgPath
    }
}
