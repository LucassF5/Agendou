import SwiftUI

/// The dimmed screen with a cut-out over the highlighted element and the balloon next to it.
/// When the element has not reported its frame yet, the balloon sits in the middle without a cut-out.
struct TourOverlay: View {
    @Environment(TourController.self) private var tour

    var body: some View {
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
                    Rectangle()
                        .fill(.clear)
                        .frame(width: cutout.width, height: cutout.height)
                        .position(x: cutout.midX, y: cutout.midY)
                        .accessibilityElement()
                        .accessibilityLabel("Área destacada")
                        .accessibilityIdentifier("tour.cutout")
                        .allowsHitTesting(false)
                }

                balloon
                    .frame(maxWidth: min(proxy.size.width - 32, 420))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity, alignment: alignment(for: cutout, in: bounds))
                    .padding(.vertical, 24)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: tour.step)
        .task(id: tour.step) { await locateBarItem() }
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
