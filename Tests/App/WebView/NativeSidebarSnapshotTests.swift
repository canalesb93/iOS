import Foundation
@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct NativeSidebarSnapshotTests {
    private static let sidebarSize = CGSize(width: 320, height: 760)

    private func panel(_ path: String, component: String = "lovelace", title: String) -> HAPanel {
        HAPanel(
            icon: nil,
            title: title,
            path: path,
            component: component,
            showInSidebar: true,
            defaultVisible: nil,
            rawTitle: title
        )
    }

    private func makeUserDefaults(_ name: String) -> UserDefaults {
        let suiteName = "NativeSidebarSnapshotTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Without a live connection `MacSidebarViewModel` only knows what its cached snapshot gives it; with
    /// nothing cached the sidebar shows just the fixed rows (Notifications, Profile) and no panels.
    private func makeViewModel(populated: Bool) -> NativeSidebarViewModel {
        let server = ServerFixture.standard
        let store = MacSidebarSnapshotStore(userDefaults: makeUserDefaults(populated ? "populated" : "empty"))
        if populated {
            store.store(
                MacSidebarSnapshot(
                    panels: [
                        panel("home", component: "home", title: "Overview"),
                        panel("map", component: "map", title: "Map"),
                        panel("energy", component: "energy", title: "Energy"),
                        panel("logbook", component: "logbook", title: "Logbook"),
                        panel("history", component: "history", title: "History"),
                        panel("config", component: "config", title: "Settings"),
                    ],
                    panelOrder: ["home", "map", "energy", "logbook", "history"],
                    hiddenPanels: [],
                    isAdmin: true,
                    userName: "Bruno"
                ),
                for: server.identifier.rawValue
            )
        }
        let overlayState = WebFrontendOverlayState()
        return NativeSidebarViewModel(
            sidebar: MacSidebarViewModel(server: server, overlayState: overlayState, snapshotStore: store),
            overlayState: overlayState,
            servers: { [server] }
        )
    }

    private func item(_ id: String, title: String, badge: Int = 0) -> MacSidebarItem {
        MacSidebarItem(
            id: id,
            kind: id == "notifications" ? .notifications : .panel(path: "/\(id)"),
            title: title,
            icon: .material(id == "notifications" ? .bellIcon : .viewDashboardIcon),
            badge: badge
        )
    }

    // MARK: - Row

    @Test func rowSelected() {
        assertLightDarkSnapshots(
            of: NativeSidebarRow(
                item: item("home", title: "Overview"),
                isSelected: true,
                accentColor: .haPrimary,
                action: {}
            )
            .padding(),
            layout: .fixed(width: 320, height: 80)
        )
    }

    @Test func rowUnselected() {
        assertLightDarkSnapshots(
            of: NativeSidebarRow(
                item: item("map", title: "Map"),
                isSelected: false,
                accentColor: .haPrimary,
                action: {}
            )
            .padding(),
            layout: .fixed(width: 320, height: 80)
        )
    }

    @Test func rowWithBadge() {
        assertLightDarkSnapshots(
            of: NativeSidebarRow(
                item: item("notifications", title: "Notifications", badge: 3),
                isSelected: false,
                accentColor: .haPrimary,
                action: {}
            )
            .padding(),
            layout: .fixed(width: 320, height: 80)
        )
    }

    // MARK: - Sidebar

    @Test func sidebarWithPanels() {
        let viewModel = makeViewModel(populated: true)
        assertLightDarkSnapshots(
            of: ZStack(alignment: .leading) {
                NativeSidebarBackdrop(accentColor: .haPrimary)
                NativeSidebarView(viewModel: viewModel, accentColor: .haPrimary)
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.sidebarSize.width, height: Self.sidebarSize.height)
        )
    }

    @Test func sidebarWithoutServerData() {
        let viewModel = makeViewModel(populated: false)
        assertLightDarkSnapshots(
            of: ZStack(alignment: .leading) {
                NativeSidebarBackdrop(accentColor: .haPrimary)
                NativeSidebarView(viewModel: viewModel, accentColor: .haPrimary)
            },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.sidebarSize.width, height: Self.sidebarSize.height)
        )
    }

    // MARK: - Edit

    @Test func editView() {
        let viewModel = makeViewModel(populated: true)
        assertLightDarkSnapshots(
            of: NativeSidebarEditView(viewModel: viewModel),
            layout: .fixed(width: 390, height: 600)
        )
    }
}
