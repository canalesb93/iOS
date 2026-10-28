import Foundation
import HAKit
@testable import HomeAssistant
import Testing

@MainActor
struct NativeNotificationsViewModelTests {
    private static func event(_ type: String, _ notifications: [String: [String: Any]]) throws
        -> NativeNotificationsEvent {
        try NativeNotificationsEvent(data: .dictionary(["type": type, "notifications": notifications]))
    }

    private static func payload(_ id: String, title: String? = nil, createdAt: String? = nil) -> [String: Any] {
        var result: [String: Any] = ["notification_id": id, "message": "Message \(id)"]
        result["title"] = title ?? NSNull()
        result["created_at"] = createdAt
        return result
    }

    @Test("Snapshots replace, changes merge, removals subtract, unknown types are ignored")
    func applyEvents() throws {
        let viewModel = NativeNotificationsViewModel(notifications: [])

        viewModel.apply(try Self.event("current", ["a": Self.payload("a"), "b": Self.payload("b")]))
        #expect(Set(viewModel.notifications.map(\.id)) == ["a", "b"])

        viewModel.apply(try Self.event("added", ["c": Self.payload("c")]))
        #expect(Set(viewModel.notifications.map(\.id)) == ["a", "b", "c"])

        viewModel.apply(try Self.event("updated", ["a": Self.payload("a", title: "New title")]))
        #expect(viewModel.notifications.first { $0.id == "a" }?.title == "New title")

        viewModel.apply(try Self.event("removed", ["b": Self.payload("b")]))
        #expect(Set(viewModel.notifications.map(\.id)) == ["a", "c"])

        viewModel.apply(try Self.event("something_new", ["z": Self.payload("z")]))
        #expect(Set(viewModel.notifications.map(\.id)) == ["a", "c"])

        viewModel.apply(try Self.event("current", ["x": Self.payload("x")]))
        #expect(viewModel.notifications.map(\.id) == ["x"])
    }

    @Test("Notifications are sorted newest first, undated last")
    func sorting() throws {
        let viewModel = NativeNotificationsViewModel(notifications: [])
        viewModel.apply(try Self.event("current", [
            "old": Self.payload("old", createdAt: "2026-01-01T10:00:00+00:00"),
            "new": Self.payload("new", createdAt: "2026-03-01T10:00:00.123456+00:00"),
            "undated": Self.payload("undated"),
        ]))
        #expect(viewModel.notifications.map(\.id) == ["new", "old", "undated"])
    }

    @Test("Empty titles decode to nil and the key stands in for a missing id")
    func decoding() {
        let item = NativeNotificationItem(key: "k", dictionary: ["title": "  ", "message": "Hi"])
        #expect(item.id == "k")
        #expect(item.title == nil)
        #expect(item.message == "Hi")
    }

    @Test("Dismissing removes optimistically and keeps the removal on success")
    func dismissSuccess() async {
        var dismissed: [String] = []
        let viewModel = NativeNotificationsViewModel(
            notifications: [.init(id: "a", message: "A"), .init(id: "b", message: "B")],
            dismissAction: { dismissed.append($0) }
        )
        await viewModel.dismiss(id: "a")
        #expect(viewModel.notifications.map(\.id) == ["b"])
        #expect(dismissed == ["a"])
        #expect(viewModel.dismissError == nil)
    }

    @Test("A failed dismissal rolls the notification back and reports the error")
    func dismissRollback() async {
        let viewModel = NativeNotificationsViewModel(
            notifications: [.init(id: "a", message: "A")],
            dismissAction: { _ in throw URLError(.notConnectedToInternet) }
        )
        await viewModel.dismiss(id: "a")
        #expect(viewModel.notifications.map(\.id) == ["a"])
        #expect(viewModel.dismissError != nil)
    }

    @Test("Dismiss all only rolls back the notifications that failed")
    func dismissAllPartialFailure() async {
        let viewModel = NativeNotificationsViewModel(
            notifications: [.init(id: "a", message: "A"), .init(id: "b", message: "B")],
            dismissAction: { id in
                if id == "b" { throw URLError(.timedOut) }
            }
        )
        await viewModel.dismissAll()
        #expect(viewModel.notifications.map(\.id) == ["b"])
        #expect(viewModel.dismissError != nil)
    }
}
