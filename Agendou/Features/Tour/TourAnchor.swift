import SwiftUI

extension View {
    /// Marks the element the tour highlights on `step`.
    func tourAnchor(_ step: TourStep) -> some View {
        modifier(TourAnchorModifier(step: step))
    }
}

extension View {
    /// Marks the element only when `condition` holds, e.g. the first row of a list.
    @ViewBuilder
    func tourAnchor(_ step: TourStep, when condition: Bool) -> some View {
        if condition { tourAnchor(step) } else { self }
    }
}

/// Finds a toolbar button of the app (outside the tour's window), in window coordinates, by the title of its
/// bar button item. Inside a toolbar, SwiftUI reports frames relative to the button itself, and the button's
/// accessibility identifier only reaches UIKit's views while an assistive technology or a UI test runs.
@MainActor
enum BarItemFrame {
    static func find(_ title: String) -> CGRect? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows where window.windowLevel == .normal {
            if let item = search(window, title), let frame = item.frame(in: window), !frame.isEmpty { return frame }
        }
        return nil
    }

    private static func search(_ view: UIView, _ title: String) -> UIBarButtonItem? {
        if let bar = view as? UINavigationBar, let navigationItem = bar.topItem {
            let groups = navigationItem.leadingItemGroups + navigationItem.trailingItemGroups
            let items =
                groups.flatMap(\.barButtonItems) + (navigationItem.leftBarButtonItems ?? [])
                + (navigationItem.rightBarButtonItems ?? [])
            if let item = items.first(where: { $0.title == title }) { return item }
        }
        for subview in view.subviews {
            if let match = search(subview, title) { return match }
        }
        return nil
    }
}

private struct TourAnchorModifier: ViewModifier {
    let step: TourStep
    @Environment(TourController.self) private var tour: TourController?

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { frame in
            tour?.anchors[step] = frame
        }
    }
}
