import Shared
import SwiftUI
import UIKit

/// The drawer's position and the physics that move it.
///
/// `progress` runs from 0 (closed, content covering the screen) to 1 (open, sidebar revealed). It tracks the
/// finger one-to-one while a drag is in flight and is handed to a velocity-matched spring when the drag ends,
/// so a flick carries its speed into the settle and a slow drag settles gently. Past fully open it resists
/// like a scroll view's edge instead of stopping dead.
@MainActor
final class NativeSidebarDrawerState: ObservableObject {
    private enum Constants {
        /// How much of the remaining travel a release must be projected past to commit to the other side.
        static let commitThreshold: CGFloat = 0.5
        /// Releases slower than this (points per second) are decided by position alone.
        static let flickVelocity: CGFloat = 300
        /// Spring velocities are clamped so a violent flick can't overshoot visibly.
        static let maximumRelativeVelocity: CGFloat = 12
    }

    /// 0 closed … 1 open, slightly above 1 while rubber-banding.
    @Published private(set) var progress: CGFloat = 0
    /// Where the drawer is settling to, as opposed to where it is mid-animation.
    @Published private(set) var isOpen = false
    @Published private(set) var isInteracting = false
    /// iPad: the docked column's visibility.
    @Published var isDockedSidebarVisible = true
    /// Whether the container currently lays the sidebar out as a docked column rather than a drawer.
    var isDockedLayout = false

    /// Width of the revealed sidebar, kept current by the container's layout.
    var drawerWidth: CGFloat = 320
    var reduceMotion = false

    private var dragStartProgress: CGFloat = 0
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Programmatic

    func open() {
        settle(open: true, velocity: 0)
    }

    func close() {
        settle(open: false, velocity: 0)
    }

    func toggle() {
        settle(open: !isOpen, velocity: 0)
    }

    /// Nudges the closed card aside and lets it fall back: a one-time hint that the drawer is behind it.
    /// Returns whether it played.
    @discardableResult
    func peek() -> Bool {
        guard !isOpen, !isInteracting, !reduceMotion, progress == 0 else { return false }
        withAnimation(DesignSystem.Motion.spring(duration: 0.32, bounce: 0)) {
            progress = 0.14
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self, !isOpen, !isInteracting else { return }
            withAnimation(DesignSystem.Motion.spring(duration: 0.5, bounce: 0.35)) {
                self.progress = 0
            }
        }
        return true
    }

    // MARK: - Interactive

    func beginInteraction() {
        isInteracting = true
        dragStartProgress = progress
        feedback.prepare()
    }

    /// `translation` is horizontal, in points, positive to the right.
    func updateInteraction(translation: CGFloat) {
        if !isInteracting {
            beginInteraction()
        }
        let raw = dragStartProgress + translation / max(drawerWidth, 1)
        let resolved: CGFloat
        if raw > 1 {
            resolved = 1 + DesignSystem.Motion.rubberBand(raw - 1, dimension: 1, coefficient: 0.35)
        } else {
            resolved = max(0, raw)
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = resolved
        }
    }

    /// `velocity` is horizontal, in points per second, positive to the right.
    func endInteraction(translation: CGFloat, velocity: CGFloat) {
        guard isInteracting else { return }
        isInteracting = false
        let width = max(drawerWidth, 1)
        let current = dragStartProgress + translation / width
        let shouldOpen: Bool
        if abs(velocity) > Constants.flickVelocity {
            shouldOpen = velocity > 0
        } else {
            let projected = current + DesignSystem.Motion.project(velocity: velocity) / width
            shouldOpen = projected > Constants.commitThreshold
        }
        settle(open: shouldOpen, velocity: velocity)
    }

    func cancelInteraction() {
        guard isInteracting else { return }
        isInteracting = false
        settle(open: isOpen, velocity: 0)
    }

    // MARK: - Settling

    private func settle(open: Bool, velocity: CGFloat) {
        let target: CGFloat = open ? 1 : 0
        if open != isOpen {
            feedback.impactOccurred(intensity: open ? 0.7 : 0.5)
        }
        isOpen = open
        guard !reduceMotion else {
            withAnimation(DesignSystem.Animation.default) {
                progress = target
            }
            return
        }
        let distance = target - progress
        var relativeVelocity: CGFloat = 0
        if abs(distance) > 0.001 {
            relativeVelocity = (velocity / max(drawerWidth, 1)) / distance
            relativeVelocity = min(max(relativeVelocity, 0), Constants.maximumRelativeVelocity)
        }
        withAnimation(DesignSystem.Motion.drawer(relativeVelocity: relativeVelocity)) {
            progress = target
        }
    }
}
