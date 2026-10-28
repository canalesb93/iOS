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
- Left screen edge on a **sub-page** (`/config/areas/...`) → interactive pop (see *Page transitions*).
- When open: drag the content card or the sidebar left, or tap the card, to close.
- Hamburger in the frontend → open (animated). The frontend hides its menu button when an app claims the sidebar
  (`hasSidebar`), so the app keeps `hasSidebar` off, forces `dockedSidebar = always_hidden` (button visible at every
  width) and intercepts `hass-toggle-menu` in a capture listener (`NativeSidebarBridgeScript`). Switching back to
  the web menu restores whatever `dockedSidebar` the user had.

## Page transitions

`PageTransitions/FrontendPageTransitionController` gives the single live web view navigation-stack motion:

- Each page is photographed on touch-down (just before a tap navigates away) and once its route settles.
- `FrontendRouteHistory` classifies route changes: push (deeper), pop (back to a page in the stack), reset
  (top-level destination / sidebar `replace`), with instant frontend forwards treated as redirects.
- Push: live view slides in from the trailing edge over the previous page's photo (parallax 0.3, dim 0.12).
- Pop (frontend back arrow): the left page's photo slides off, uncovering the live view.
- Interactive pop: live view follows the finger over the previous photo; commit on 50% or a flick, then the
  photo covers the swap while `goBack()` runs.
- Sidebar panel switches cross-fade.

## Status

| Area | State |
|---|---|
| Native sidebar (iPhone drawer, iPad docked) | ✅ verified on simulator against a demo HA |
| Interactive push/pop between frontend pages | ✅ verified |
| Native notifications sheet | ✅ built, unit + snapshot tested |
| Sheets → `NavigationStack`, detents, system close | ✅ |
| Server-switch transition, first-run peek | ✅ |
| 120 Hz (`CADisableMinimumFrameDurationOnPhone`) | ✅ |

## Verifying

- Unit/snapshot: `xcodebuild test -scheme Tests-Unit -only-testing:Tests-App/NativeSidebarRouteTests …`
- Visual tour: `SIM_UDID=<udid> Tools/redesign/run-tour.sh <credentials-file> <out-dir>` runs
  `NativeSidebarTourTests` against a local Home Assistant and exports screenshots + the screen recording. The
  credentials file is `url=…`, `username=…`, `password=…` and never lives in the repo.
- Simulator builds need `Configuration/HomeAssistant.overrides.xcconfig` (git-ignored) with
  `CODE_SIGN_IDENTITY[sdk=iphonesimulator*] = -` (plus empty team/profile) so the app-group entitlement is kept;
  unsigned builds crash at launch in `AppConstants.AppGroupContainer`.

## Ownership map (for parallel work)

| Area | Paths |
|---|---|
| Sidebar + navigation style + gestures | `Sources/App/Frontend/WebView/NativeSidebar/**`, `HomeAssistantView*`, `WebViewController+Gestures/Navigation`, `WebViewExternalBusMessage.configResult`, `NativeTabBarState` |
| Sheet modernisation | `Sources/App/Settings/**`, `Assist/**`, `WhatsNew/**`, `Servers/**`, `DownloadManager/**`, `PermissionScreen/**`, `Onboarding/Views/**`, `HADesignSystem` `CloseButton` |
| Native notifications sheet | `Sources/App/Frontend/WebView/NativeNotifications/**` |
| Page transitions | `Sources/App/Frontend/WebView/PageTransitions/**` |

## Building

`Tools/redesign/build-sim.sh [derived-data-path]` — unsigned simulator build. Use a distinct derived-data path
per worktree.
