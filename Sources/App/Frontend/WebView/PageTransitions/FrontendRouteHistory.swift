import Foundation

/// The app's own record of how the user moved through the frontend, so a route change can be told apart as
/// drilling in (push), coming back (pop) or jumping somewhere new (reset). WebKit's back/forward list can't
/// answer that: it doesn't say which way a pop went, and the frontend replaces entries freely.
struct FrontendRouteHistory {
    enum Change: Equatable {
        /// A page deeper than `from` opened.
        case push(from: String)
        /// The user came back to a page already in the stack, leaving `from`.
        case pop(from: String)
        /// A different top-level destination, or the first page.
        case reset
        /// The path didn't change (a query or fragment change, or a repeated report).
        case none
    }

    private(set) var stack: [String] = []
    /// Set just before the sidebar swaps panels with `replace: true`; the next change starts a new stack.
    var expectsReplace = false

    var current: String? { stack.last }
    var previous: String? { stack.count > 1 ? stack[stack.count - 2] : nil }
    var canPop: Bool { stack.count > 1 }

    /// `isRedirect` marks a change that followed a push too quickly to be the user's doing — the frontend
    /// forwarding `/config/areas` to `/config/areas/dashboard`, say. It replaces the page it forwarded from
    /// instead of stacking on top of it, so going back skips the page nobody saw.
    @discardableResult
    mutating func update(to path: String, isRedirect: Bool = false) -> Change {
        guard stack.last != path else { return .none }
        if isRedirect, !expectsReplace, stack.count > 1, !stack.contains(path), !NativeSidebarRoute.isRoot(path) {
            stack[stack.count - 1] = path
            return .none
        }
        if expectsReplace {
            expectsReplace = false
            stack = [path]
            return .reset
        }
        if let index = stack.lastIndex(of: path), let from = stack.last {
            stack.removeSubrange((index + 1)...)
            return .pop(from: from)
        }
        guard let from = stack.last, !NativeSidebarRoute.isRoot(path) else {
            stack = [path]
            return .reset
        }
        stack.append(path)
        return .push(from: from)
    }
}
