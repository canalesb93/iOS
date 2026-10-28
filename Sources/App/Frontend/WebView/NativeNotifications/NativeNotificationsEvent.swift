import Foundation
import HAKit

/// One event of the `persistent_notification/subscribe` stream: a full snapshot (`current`) or an
/// incremental change (`added`, `updated`, `removed`) carrying the affected notifications by id.
struct NativeNotificationsEvent: HADataDecodable, Equatable {
    enum ChangeType: String, Equatable {
        case current
        case added
        case updated
        case removed
        /// A change type this app version doesn't know; ignored rather than failing the stream.
        case unknown
    }

    var type: ChangeType
    var notifications: [NativeNotificationItem]

    init(type: ChangeType, notifications: [NativeNotificationItem]) {
        self.type = type
        self.notifications = notifications
    }

    init(data: HAData) throws {
        let rawType: String = try data.decode("type")
        self.type = ChangeType(rawValue: rawType) ?? .unknown
        let payload: [String: Any] = data.decode("notifications", fallback: [:])
        self.notifications = payload.compactMap { key, value in
            guard let dictionary = value as? [String: Any] else { return nil }
            return NativeNotificationItem(key: key, dictionary: dictionary)
        }
    }

    /// The notifications that result from applying this event to `current`.
    func apply(to current: [String: NativeNotificationItem]) -> [String: NativeNotificationItem] {
        var result = current
        switch type {
        case .current:
            result = Dictionary(notifications.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        case .added, .updated:
            notifications.forEach { result[$0.id] = $0 }
        case .removed:
            notifications.forEach { result[$0.id] = nil }
        case .unknown:
            break
        }
        return result
    }
}
