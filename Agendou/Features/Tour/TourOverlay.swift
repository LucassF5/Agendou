import SwiftUI

/// The dimmed screen with a cut-out over the highlighted element and the balloon next to it.
/// When the element has not reported its frame yet, the balloon sits in the middle without a cut-out.
struct TourOverlay: View {
    @Environment(TourController.self) private var tour

    var body: some View {
        // The outer reader keeps the safe area (live, so it follows rotation); the inner one ignores it so
        // frames match the app's global coordinates.
        GeometryReader { outer in
            let safeArea = outer.safeAreaInsets
            layer(safeArea: safeArea)
                .task(id: BarItemLookup(step: tour.step, size: outer.size)) { await locateBarItem() }
        }
    }

    private struct BarItemLookup: Equatable {
        let step: TourStep?
        let size: CGSize
    }

    private func layer(safeArea: EdgeInsets) -> some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let cutout = tour.step.flatMap { tour.anchors[$0] }.map { $0.insetBy(dx: -8, dy: -8) }
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(bounds)
                    if let cutout { path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 14, height: 14)) }
                }
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                .contentShape(Rectangle())
                .onTapGesture {}

                if let cutout {
                    // Accessibility before `.position`, which fills its parent: the element keeps the cut-out's frame.
                    Rectangle()
                        .fill(.clear)
                        .frame(width: cutout.width, height: cutout.height)
                        .accessibilityElement()
                        .accessibilityLabel("Área destacada")
                        .accessibilityIdentifier("tour.cutout")
                        .position(x: cutout.midX, y: cutout.midY)
                        .allowsHitTesting(false)
                }

                balloon
                    .frame(maxWidth: min(proxy.size.width - 32, 420))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity, alignment: alignment(for: cutout, in: bounds))
                    .padding(.top, safeArea.top + 8)
                    .padding(.bottom, safeArea.bottom + 8)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: tour.step)
    }

    /// For a toolbar button, looks it up in UIKit until its frame stops moving (the tab switch settles).
    private func locateBarItem() async {
        guard let step = tour.step, let identifier = step.barItemIdentifier else { return }
        var last: CGRect?
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            guard tour.step == step else { return }
            guard let frame = BarItemFrame.find(identifier) else { continue }
            tour.anchors[step] = frame
            if frame == last { return }
            last = frame
        }
    }

    /// Below the element when it is in the top half of the screen, above it otherwise.
    private func alignment(for cutout: CGRect?, in bounds: CGRect) -> Alignment {
        guard let cutout else { return .center }
        return cutout.midY < bounds.midY ? .bottom : .top
    }

    private var balloon: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let step = tour.step {
                Text(step.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tour.text")
            }
            HStack {
                if !(tour.isLast && tour.hasSchedule) {
                    Button("Pular") { tour.exit(.skip) }
                        .accessibilityIdentifier("tour.skip")
                }
                Spacer()
                if !tour.isLast {
                    Button("Próximo") { tour.next() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("tour.next")
                } else if tour.hasSchedule {
                    Button("Concluir") { tour.exit(.done) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("tour.done")
                } else {
                    Button("Configurar minha escala") { tour.exit(.setUp) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("tour.setup")
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tour.balloon")
    }
}
