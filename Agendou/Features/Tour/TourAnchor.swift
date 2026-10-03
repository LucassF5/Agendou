import SwiftUI

extension View {
    /// Marks the element the tour highlights on `step`.
    func tourAnchor(_ step: TourStep) -> some View {
        modifier(TourAnchorModifier(step: step))
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
