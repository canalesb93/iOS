import SFSafeSymbols
import Shared
import SwiftUI

/// The native replacement for the frontend's notification drawer: Home Assistant's persistent
/// notifications in a `NavigationStack`, dismissable one by one or all at once.
///
/// Meant to be presented as a sheet:
/// ```swift
/// .sheet(isPresented: $showNotifications) {
///     NativeNotificationsView(viewModel: NativeNotificationsViewModel(server: server))
///         .presentationDetents([.medium, .large])
///         .presentationDragIndicator(.visible)
/// }
/// ```
struct NativeNotificationsView: View {
    @StateObject private var viewModel: NativeNotificationsViewModel
    @State private var showDismissAllConfirmation = false
    private let onOpenLink: ((URL) -> Bool)?

    /// - Parameter onOpenLink: Gets first refusal on links tapped in a message, e.g. to route
    ///   Home Assistant paths into the web view. Return `true` if handled; otherwise the system opens it.
    init(viewModel: @autoclosure @escaping () -> NativeNotificationsViewModel, onOpenLink: ((URL) -> Bool)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel())
        self.onOpenLink = onOpenLink
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    if !viewModel.hasLoaded {
                        ProgressView()
                    } else if #available(iOS 17.0, *) {
                        ContentUnavailableView {
                            Label {
                                Text(L10n.NativeNotifications.Empty.title)
                            } icon: {
                                Image(systemSymbol: .bellSlash)
                            }
                        } description: {
                            Text(L10n.NativeNotifications.Empty.description)
                        }
                    } else {
                        VStack(spacing: DesignSystem.Spaces.one) {
                            Image(systemSymbol: .bellSlash)
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text(L10n.NativeNotifications.Empty.title)
                                .font(.title2.bold())
                            Text(L10n.NativeNotifications.Empty.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(DesignSystem.Spaces.four)
                    }
                } else {
                    List {
                        ForEach(viewModel.notifications) { item in
                            let markdown = (try? AttributedString(
                                markdown: item.message,
                                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                            )) ?? AttributedString(item.message)
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.one) {
                                    if let title = item.title {
                                        Text(title)
                                            .font(.headline)
                                    }
                                    Spacer(minLength: DesignSystem.Spaces.one)
                                    if let createdAt = item.createdAt {
                                        TimelineView(.everyMinute) { _ in
                                            Text(createdAt.formatted(.relative(
                                                presentation: .numeric,
                                                unitsStyle: .abbreviated
                                            )))
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                Text(markdown)
                                    .font(.subheadline)
                                    .foregroundStyle(item.title == nil ? .primary : .secondary)
                                    .tint(.haPrimary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, DesignSystem.Spaces.half)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.dismiss(id: item.id) }
                                } label: {
                                    Label(L10n.NativeNotifications.dismiss, systemSymbol: .checkmark)
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await viewModel.dismiss(id: item.id) }
                                } label: {
                                    Label(L10n.NativeNotifications.dismiss, systemSymbol: .checkmark)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: viewModel.notifications)
            .navigationTitle(L10n.NativeNotifications.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.notifications.isEmpty {
                        Button(L10n.NativeNotifications.dismissAll) {
                            showDismissAllConfirmation = true
                        }
                        .confirmationDialog(
                            L10n.NativeNotifications.DismissAll.confirmationTitle,
                            isPresented: $showDismissAllConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button(L10n.NativeNotifications.dismissAll, role: .destructive) {
                                Task { await viewModel.dismissAll() }
                            }
                            Button(L10n.cancelLabel, role: .cancel) {}
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton()
                }
            }
        }
        .modifier(NativeNotificationsDismissFeedback(trigger: viewModel.dismissCount))
        .environment(\.openURL, OpenURLAction { url in
            onOpenLink?(url) == true ? .handled : .systemAction
        })
        .alert(
            L10n.NativeNotifications.DismissFailed.title,
            isPresented: Binding(
                get: { viewModel.dismissError != nil },
                set: { if !$0 { viewModel.dismissError = nil } }
            )
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.dismissError ?? "")
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

#Preview("Notifications") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NativeNotificationsView(viewModel: NativeNotificationsViewModel(notifications: [
                NativeNotificationItem(
                    id: "a",
                    title: "Low battery",
                    message: "The **front door lock** is at 8%. See the [battery report](https://www.home-assistant.io).",
                    createdAt: Date().addingTimeInterval(-300)
                ),
                NativeNotificationItem(
                    id: "b",
                    title: "Update available",
                    message: "Home Assistant Core 2026.11.0 is ready to install.",
                    createdAt: Date().addingTimeInterval(-7200)
                ),
                NativeNotificationItem(
                    id: "c",
                    title: nil,
                    message: "Config check passed.\nNo issues found.",
                    createdAt: Date().addingTimeInterval(-86400 * 2)
                ),
            ]))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
}

#Preview("Empty") {
    NativeNotificationsView(viewModel: NativeNotificationsViewModel(notifications: []))
}
