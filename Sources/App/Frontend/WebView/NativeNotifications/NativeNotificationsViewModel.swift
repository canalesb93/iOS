import Foundation
import HAKit
import Shared

/// Drives the native notifications sheet: keeps a live copy of the server's persistent notifications
/// and dismisses them optimistically, rolling back when the server refuses.
@MainActor
final class NativeNotificationsViewModel: ObservableObject {
    /// Newest first; notifications without a creation date sink to the bottom.
    @Published private(set) var notifications: [NativeNotificationItem] = []
    /// False until the first snapshot arrives (or immediately, for injected notifications).
    @Published private(set) var hasLoaded: Bool
    /// Set when a dismissal failed and was rolled back; the view shows it in an alert.
    @Published var dismissError: String?
    /// Bumped on every successful optimistic dismissal; drives haptics.
    @Published private(set) var dismissCount = 0

    private var store: [String: NativeNotificationItem] = [:]
    /// Ids removed optimistically whose dismissal hasn't settled; events must not resurrect them.
    private var pendingDismissals: Set<String> = []
    private var tokens: [HACancellable] = []
    private let server: Server?
    private let dismissAction: (String) async throws -> Void

    /// A view model backed by the live connection of `server`.
    init(server: Server) {
        self.server = server
        self.hasLoaded = false
        self.dismissAction = { id in
            guard let connection = Current.api(for: server)?.connection else {
                throw URLError(.notConnectedToInternet)
            }
            try await connection.send(.callService(
                domain: "persistent_notification",
                service: "dismiss",
                data: ["notification_id": id]
            )).promise.asyncValue()
        }
    }

    /// A view model with fixed notifications and no server, for previews and tests.
    init(
        notifications: [NativeNotificationItem],
        dismissAction: @escaping (String) async throws -> Void = { _ in }
    ) {
        self.server = nil
        self.hasLoaded = true
        self.dismissAction = dismissAction
        self.store = Dictionary(notifications.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        publish()
    }

    deinit {
        tokens.forEach { $0.cancel() }
    }

    func start() {
        guard tokens.isEmpty, let server, let connection = Current.api(for: server)?.connection else { return }
        tokens.append(connection.subscribe(
            to: HATypedSubscription<NativeNotificationsEvent>(
                request: .init(type: "persistent_notification/subscribe")
            ),
            handler: { [weak self] _, event in
                Task { @MainActor [weak self] in
                    self?.apply(event)
                }
            }
        ))
    }

    func stop() {
        tokens.forEach { $0.cancel() }
        tokens = []
    }

    /// Applies one subscription event to the current state.
    func apply(_ event: NativeNotificationsEvent) {
        store = event.apply(to: store)
        pendingDismissals.forEach { store[$0] = nil }
        hasLoaded = true
        publish()
    }

    func dismiss(id: String) async {
        await dismiss(ids: [id])
    }

    func dismissAll() async {
        await dismiss(ids: notifications.map(\.id))
    }

    private func dismiss(ids: [String]) async {
        let removed = ids.compactMap { store[$0] }
        guard !removed.isEmpty else { return }

        for item in removed {
            store[item.id] = nil
            pendingDismissals.insert(item.id)
        }
        dismissCount += 1
        publish()

        let action = dismissAction
        var failures: [(item: NativeNotificationItem, error: Error)] = []
        await withTaskGroup(of: (NativeNotificationItem, Error?).self) { group in
            for item in removed {
                group.addTask {
                    do {
                        try await action(item.id)
                        return (item, nil)
                    } catch {
                        return (item, error)
                    }
                }
            }
            for await (item, error) in group {
                if let error {
                    failures.append((item, error))
                }
            }
        }

        for item in removed {
            pendingDismissals.remove(item.id)
        }
        guard !failures.isEmpty else { return }

        for failure in failures {
            store[failure.item.id] = failure.item
            Current.Log.error("Failed to dismiss notification \(failure.item.id): \(failure.error)")
        }
        dismissError = failures[0].error.localizedDescription
        publish()
    }

    private func publish() {
        notifications = store.values.sorted { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (l?, r?) where l != r:
                return l > r
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                return lhs.id < rhs.id
            }
        }
    }
}
