import Foundation
import HAKit

/// A Home Assistant persistent notification, as sent by `persistent_notification/subscribe`.
struct NativeNotificationItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String?
    /// Markdown, as written by whoever called `persistent_notification.create`.
    let message: String
    let createdAt: Date?

    init(id: String, title: String? = nil, message: String, createdAt: Date? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.createdAt = createdAt
    }

    /// - Parameters:
    ///   - key: The id the notification is keyed by in the event; used when the payload omits `notification_id`.
    ///   - dictionary: The notification payload.
    init(key: String, dictionary: [String: Any]) {
        let rawTitle = (dictionary["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            id: (dictionary["notification_id"] as? String) ?? key,
            title: rawTitle?.isEmpty == false ? rawTitle : nil,
            message: (dictionary["message"] as? String) ?? "",
            createdAt: dictionary["created_at"].flatMap { Date.decode(unknown: $0) }
        )
    }
}
