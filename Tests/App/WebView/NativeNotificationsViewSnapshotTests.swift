import Foundation
@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct NativeNotificationsViewSnapshotTests {
    // No creation dates: the view renders them relative to now, which a reference image can't hold.
    @Test func populated() {
        assertLightDarkSnapshots(
            of: NativeNotificationsView(viewModel: NativeNotificationsViewModel(notifications: [
                NativeNotificationItem(
                    id: "a",
                    title: "Low battery",
                    message: "The **front door lock** is at 8%."
                ),
                NativeNotificationItem(
                    id: "b",
                    title: "Update available",
                    message: "Home Assistant Core 2026.11.0 is ready to install."
                ),
                NativeNotificationItem(id: "c", message: "Config check passed.\nNo issues found."),
            ])),
            layout: .fixed(width: 390, height: 600)
        )
    }

    @Test func empty() {
        assertLightDarkSnapshots(
            of: NativeNotificationsView(viewModel: NativeNotificationsViewModel(notifications: [])),
            layout: .fixed(width: 390, height: 600)
        )
    }
}
