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

/// Finds a view of the app (outside the tour's window) by accessibility identifier, in window coordinates.
/// Used for toolbar buttons: inside a toolbar, SwiftUI reports frames relative to the button itself.
@MainActor
enum BarItemFrame {
    static func find(_ identifier: String) -> CGRect? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows where window.windowLevel == .normal {
            if let view = search(window, identifier) { return view.convert(view.bounds, to: nil) }
        }
        return nil
    }

    private static func search(_ view: UIView, _ identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for subview in view.subviews {
            if let match = search(subview, identifier) { return match }
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
