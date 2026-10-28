# Home Assistant iOS — Native Navigation Redesign (fork)

This fork reworks the app's navigation so it feels like a first-class iOS app rather than a web view with
modals bolted on. The web frontend stays the content engine; the *chrome* around it becomes native.

## Principles

1. **Native chrome, web content.** Everything that is "navigation" (switching dashboards, servers, opening
   settings/assist/notifications) is native. Everything that is "content" (dashboards, config pages) stays web.
2. **Spatial, interruptible motion.** Every transition has a physical origin (zoom from the tapped control,
   drawer from the edge) and can be grabbed mid-flight. Springs, not curves. 120 Hz on ProMotion
   (`CADisableMinimumFrameDurationOnPhone`).
3. **One way to present.** Sheets are `NavigationStack`-backed, have detents where the content is short, use
   the system close button (`Button(role: .close)` on iOS 26, `CloseButton` fallback), and never double-layer.
4. **Pushes for depth, sheets for tasks.** Drill-down = push inside a stack. Self-contained task = sheet.
   Immersive, full-attention = zoom full-screen cover (Assist, cameras).
5. **Respect the platform.** Reduce Motion swaps springs for cross-fades. Dynamic Type everywhere. Haptics
   via `.sensoryFeedback` on state changes, never on every frame.

## Navigation styles

`Settings ▸ General ▸ Navigation` picks one of:

| Style | iPhone | iPad (regular width) |
|---|---|---|
| **Sidebar** (default) | Interactive drawer: content card slides & scales away from the left edge, sidebar revealed underneath with parallax | Docked, collapsible sidebar column |
| **Tab bar** (iOS 26) | Existing `NativeTabBar` (formerly App Labs) | Same |
| **Web** | Frontend's own hamburger drawer (upstream behaviour) | Same |

Sidebar and Tab bar both set `hasSidebar: true` in `config/get`, so the frontend's hamburger sends
`sidebar/show` to native instead of opening its own drawer.

## The sidebar

- Data: `MacSidebarViewModel` (panels, user-data order/hidden, default panel, admin, notifications badge).
- Header: account avatar + server name; tap → server menu / server picker (zoom).
- Quick actions row: Search (frontend quick bar), Assist (zoom from the button).
- Panels list with a sliding selection indicator (matched geometry) that follows the current route.
- Footer: Notifications (badge), Profile, App Settings (zoom into settings sheet).
- Edit mode: reorder + hide/show, persisted to frontend user data like the web sidebar.
- Panel switches navigate with `replace: true` — switching root, not pushing history.

### Gestures

- Left screen edge at a **panel root** → interactive drawer open (tracks finger, velocity-projected spring settle,
  rubber-band past fully open).
- Left screen edge on a **sub-page** (`/config/areas/...`) → native interactive back
  (`WKWebView.allowsBackForwardNavigationGestures`).
- When open: drag the content card or the sidebar left, or tap the card, to close.
- Hamburger in the frontend → open (animated).

## Ownership map (for parallel work)

| Area | Paths |
|---|---|
| Sidebar + navigation style + gestures | `Sources/App/Frontend/WebView/NativeSidebar/**`, `HomeAssistantView*`, `WebViewController+Gestures/Navigation`, `WebViewExternalBusMessage.configResult`, `NativeTabBarState` |
| Sheet modernisation | `Sources/App/Settings/**`, `Assist/**`, `WhatsNew/**`, `Servers/**`, `DownloadManager/**`, `PermissionScreen/**`, `Onboarding/Views/**`, `HADesignSystem` `CloseButton` |
| Native notifications sheet | `Sources/App/Frontend/WebView/NativeNotifications/**` |

## Building

`Tools/redesign/build-sim.sh [derived-data-path]` — unsigned simulator build. Use a distinct derived-data path
per worktree.
