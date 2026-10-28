import Shared
import SwiftUI

/// Lays the sidebar and the frontend out together.
///
/// - Compact width: a drawer. The content becomes a card that slides and shrinks to the right, revealing the
///   sidebar underneath with a parallax lag, following `NativeSidebarDrawerState.progress` frame by frame.
/// - Regular width: a docked column the content sits beside, collapsible from the frontend's menu button.
///
/// Both layouts are the same view tree with different modifier values, so rotating an iPad or resizing a
/// window never tears down the web view inside `content`.
struct NativeSidebarContainerView<Sidebar: View, Content: View>: View {
    @ObservedObject var drawer: NativeSidebarDrawerState
    let isDocked: Bool
    /// Off, the content simply fills the container: the sidebar is another navigation style's, or there is
    /// nothing to navigate yet (the stand-by screen is up).
    var isEnabled = true
    let accentColor: Color
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets
            let docked = isEnabled && isDocked
            let drawerWidth = min(
                (size.width + insets.leading) * NativeSidebarLayout.drawerWidthFraction,
                NativeSidebarLayout.maximumDrawerWidth
            )
            // Drawer effects stop at fully open; only the card keeps travelling while rubber-banding.
            let progress = docked || !isEnabled ? 0 : drawer.progress
            let revealed = min(progress, 1)
            let dockedInset = docked && drawer.isDockedSidebarVisible ? NativeSidebarLayout.dockedWidth : 0
            let showsSidebar = isEnabled && (docked ? drawer.isDockedSidebarVisible : progress > 0.001)
            let showsCardChrome = progress > 0.001
            let cardShape = NativeSidebarCardShape(
                outsets: insets,
                cornerRadius: showsCardChrome ? NativeSidebarLayout.cardCornerRadius * revealed : 0
            )

            ZStack(alignment: .topLeading) {
                NativeSidebarBackdrop(accentColor: accentColor)
                    .opacity(showsSidebar ? 1 : 0)
                    .ignoresSafeArea()

                sidebar()
                    .frame(width: docked ? NativeSidebarLayout.dockedWidth : drawerWidth)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(
                        docked ? 1 : 1 - NativeSidebarLayout.sidebarScaleReduction * (1 - revealed),
                        anchor: .leading
                    )
                    .offset(x: docked
                        ? (drawer.isDockedSidebarVisible ? 0 : -NativeSidebarLayout.dockedWidth)
                        : -(1 - revealed) * drawerWidth * NativeSidebarLayout.sidebarParallax)
                    .opacity(showsSidebar ? (docked ? 1 : Double(0.25 + 0.75 * revealed)) : 0)
                    .allowsHitTesting(showsSidebar && (docked || drawer.isOpen))
                    .accessibilityHidden(!showsSidebar || (!docked && !drawer.isOpen))
                    .simultaneousGesture(closeDragGesture, including: docked ? .none : .all)

                content()
                    .frame(width: size.width - dockedInset, height: size.height)
                    .clipShape(cardShape)
                    .overlay {
                        if showsCardChrome {
                            // Catches touches while open: a tap or a drag on the card closes the drawer.
                            cardShape
                                .fill(Color.black.opacity(NativeSidebarLayout.contentDimming * Double(revealed)))
                                .contentShape(cardShape)
                                .onTapGesture { drawer.close() }
                                .gesture(closeDragGesture)
                                .accessibilityLabel(L10n.NativeSidebar.Accessibility.closeSidebar)
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .background {
                        cardShape
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(
                                color: .black.opacity(NativeSidebarLayout.shadowOpacity * Double(revealed)),
                                radius: NativeSidebarLayout.shadowRadius * revealed,
                                x: -4 * revealed
                            )
                            .opacity(showsCardChrome ? 1 : 0)
                    }
                    .scaleEffect(1 - NativeSidebarLayout.contentScaleReduction * revealed, anchor: .leading)
                    .offset(x: dockedInset + progress * drawerWidth)
                    .accessibilityHidden(!docked && drawer.isOpen)
            }
            .onAppear {
                drawer.drawerWidth = drawerWidth
                drawer.isDockedLayout = docked
                drawer.reduceMotion = reduceMotion
            }
            .onChange(of: drawerWidth) { drawer.drawerWidth = $0 }
            .onChange(of: docked) { newValue in
                drawer.isDockedLayout = newValue
                // A drawer left open while the window grew into a docked layout would come back open later.
                if newValue, drawer.isOpen {
                    drawer.close()
                }
            }
            .onChange(of: isEnabled) { newValue in
                if !newValue, drawer.isOpen {
                    drawer.close()
                }
            }
            .onChange(of: reduceMotion) { drawer.reduceMotion = $0 }
        }
        .accessibilityAction(.escape) {
            if drawer.isOpen {
                drawer.close()
            }
        }
    }

    /// Closing drags, measured globally: the card moves under the finger, so a local coordinate space would
    /// feed the drag's own motion back into it.
    private var closeDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard drawer.isOpen || drawer.isInteracting else { return }
                let translation = value.translation
                // Leave vertical scrolling in the sidebar alone until the drag is clearly horizontal.
                guard drawer.isInteracting || abs(translation.width) > abs(translation.height) else { return }
                drawer.updateInteraction(translation: min(translation.width, 0) + max(translation.width, 0) * 0.5)
            }
            .onEnded { value in
                guard drawer.isInteracting else { return }
                let velocity = value.predictedEndTranslation.width - value.translation.width
                drawer.endInteraction(translation: value.translation.width, velocity: velocity * 4)
            }
    }
}

#Preview {
    let drawer = NativeSidebarDrawerState()
    return NativeSidebarContainerView(drawer: drawer, isDocked: false, accentColor: .haPrimary) {
        List(0 ..< 8) { Text("Panel \($0)") }
            .scrollContentBackground(.hidden)
    } content: {
        ZStack {
            Color.blue.opacity(0.2)
            Button("Toggle") { drawer.toggle() }
        }
    }
}
