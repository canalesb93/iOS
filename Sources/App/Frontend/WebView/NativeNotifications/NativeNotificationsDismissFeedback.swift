import SwiftUI

/// Plays a success haptic each time `trigger` changes; a no-op before iOS 17, where
/// `sensoryFeedback` doesn't exist.
struct NativeNotificationsDismissFeedback<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.sensoryFeedback(.success, trigger: trigger)
        } else {
            content
        }
    }
}

#Preview {
    Text("Haptics on change")
        .modifier(NativeNotificationsDismissFeedback(trigger: 0))
}
