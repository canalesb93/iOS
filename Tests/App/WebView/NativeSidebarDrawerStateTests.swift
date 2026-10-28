import CoreGraphics
@testable import HomeAssistant
import Testing

@MainActor
struct NativeSidebarDrawerStateTests {
    private static let width: CGFloat = 320

    private func makeState(open: Bool = false) -> NativeSidebarDrawerState {
        let state = NativeSidebarDrawerState()
        state.drawerWidth = Self.width
        if open {
            state.open()
        }
        return state
    }

    // MARK: - Programmatic

    @Test func openAndCloseSetIsOpen() {
        let state = makeState()
        #expect(!state.isOpen)
        state.open()
        #expect(state.isOpen)
        state.close()
        #expect(!state.isOpen)
    }

    @Test func toggleFlipsIsOpen() {
        let state = makeState()
        state.toggle()
        #expect(state.isOpen)
        state.toggle()
        #expect(!state.isOpen)
    }

    @Test func reduceMotionStillSettlesToTheTarget() {
        let state = makeState()
        state.reduceMotion = true
        state.open()
        #expect(state.isOpen)
        state.close()
        #expect(!state.isOpen)
    }

    // MARK: - Interactive

    @Test func progressFollowsTheFingerWhileDragging() {
        let state = makeState()
        state.beginInteraction()
        #expect(state.isInteracting)
        state.updateInteraction(translation: Self.width / 2)
        #expect(abs(state.progress - 0.5) < 0.001)
        state.updateInteraction(translation: Self.width / 4)
        #expect(abs(state.progress - 0.25) < 0.001)
    }

    @Test func updatingWithoutBeginningStartsTheInteraction() {
        let state = makeState()
        state.updateInteraction(translation: 10)
        #expect(state.isInteracting)
    }

    @Test func releaseBeyondHalfwayOpens() {
        let state = makeState()
        state.beginInteraction()
        state.updateInteraction(translation: Self.width * 0.6)
        state.endInteraction(translation: Self.width * 0.6, velocity: 0)
        #expect(!state.isInteracting)
        #expect(state.isOpen)
    }

    @Test func slowReleaseBeforeHalfwayCloses() {
        let state = makeState()
        state.beginInteraction()
        state.updateInteraction(translation: Self.width * 0.3)
        state.endInteraction(translation: Self.width * 0.3, velocity: 50)
        #expect(!state.isOpen)
    }

    @Test func slowReleaseFromOpenBeforeHalfwayCloses() {
        let state = makeState(open: true)
        state.beginInteraction()
        state.updateInteraction(translation: -Self.width * 0.6)
        state.endInteraction(translation: -Self.width * 0.6, velocity: 0)
        #expect(!state.isOpen)
    }

    @Test func slowReleaseFromOpenAfterHalfwayStaysOpen() {
        let state = makeState(open: true)
        state.beginInteraction()
        state.updateInteraction(translation: -Self.width * 0.3)
        state.endInteraction(translation: -Self.width * 0.3, velocity: 0)
        #expect(state.isOpen)
    }

    @Test func fastRightwardFlickFromNearClosedOpens() {
        let state = makeState()
        state.beginInteraction()
        state.updateInteraction(translation: 20)
        state.endInteraction(translation: 20, velocity: 1200)
        #expect(state.isOpen)
    }

    @Test func fastLeftwardFlickFromOpenCloses() {
        let state = makeState(open: true)
        state.beginInteraction()
        state.updateInteraction(translation: -20)
        state.endInteraction(translation: -20, velocity: -1200)
        #expect(!state.isOpen)
    }

    @Test func flickDirectionBeatsPositionWhenFast() {
        // Dragged most of the way open, but flicked back left: closes.
        let state = makeState()
        state.beginInteraction()
        state.updateInteraction(translation: Self.width * 0.8)
        state.endInteraction(translation: Self.width * 0.8, velocity: -900)
        #expect(!state.isOpen)
    }

    @Test func draggingPastFullyOpenRubberBands() {
        let state = makeState()
        let translation = Self.width * 2
        state.beginInteraction()
        state.updateInteraction(translation: translation)
        #expect(state.progress > 1)
        // Without resistance the drawer would be at 3x; the band keeps it close to fully open.
        #expect(state.progress < 1 + translation / Self.width)
        #expect(state.progress < 1.5)

        let before = state.progress
        state.updateInteraction(translation: translation * 2)
        #expect(state.progress > before)
        #expect(state.progress < 2)
    }

    @Test func negativeTranslationFromClosedClampsAtZero() {
        let state = makeState()
        state.beginInteraction()
        state.updateInteraction(translation: -200)
        #expect(state.progress == 0)
    }

    @Test func releasePastFullyOpenOpens() {
        let state = makeState()
        state.beginInteraction()
        state.updateInteraction(translation: Self.width * 1.5)
        state.endInteraction(translation: Self.width * 1.5, velocity: 0)
        #expect(state.isOpen)
    }

    @Test func cancelReturnsToTheRestingStateItStartedFrom() {
        let closed = makeState()
        closed.beginInteraction()
        closed.updateInteraction(translation: Self.width * 0.8)
        closed.cancelInteraction()
        #expect(!closed.isInteracting)
        #expect(!closed.isOpen)

        let open = makeState(open: true)
        open.beginInteraction()
        open.updateInteraction(translation: -Self.width * 0.8)
        open.cancelInteraction()
        #expect(!open.isInteracting)
        #expect(open.isOpen)
    }

    @Test func endingWithoutAnInteractionDoesNothing() {
        let state = makeState()
        state.endInteraction(translation: Self.width, velocity: 2000)
        #expect(!state.isOpen)
        state.cancelInteraction()
        #expect(!state.isOpen)
    }

    @Test func interactionStartsFromWhereTheDrawerRests() {
        let state = makeState(open: true)
        state.beginInteraction()
        state.updateInteraction(translation: 0)
        #expect(abs(state.progress - 1) < 0.001)
    }
}
