import CoreGraphics
import Observation

/// Where the tour is and where the highlighted elements are on screen.
@Observable
final class TourController {
    enum Exit {
        /// "Pular", on any step.
        case skip
        /// "Concluir", on the last step when a real schedule exists.
        case done
        /// "Configurar minha escala", on the last step otherwise.
        case setUp
    }

    private(set) var step: TourStep?
    /// Whether the real agenda has a schedule; decides the last button.
    private(set) var hasSchedule = false
    /// Global frames reported by `.tourAnchor`. Cleared when a run starts; the screens are rebuilt at the
    /// same moment (see `RootTabView`), so every frame comes from the screens the tour is showing.
    var anchors: [TourStep: CGRect] = [:]
    @ObservationIgnored var onExit: ((Exit) -> Void)?

    var isActive: Bool {
        step != nil
    }

    var isLast: Bool {
        step == TourStep.allCases.last
    }

    func start(hasSchedule: Bool) {
        self.hasSchedule = hasSchedule
        anchors = [:]
        step = TourStep.allCases.first
    }

    func next() {
        guard let step, let following = TourStep(rawValue: step.rawValue + 1) else { return }
        self.step = following
    }

    func exit(_ reason: Exit) {
        guard isActive else { return }
        step = nil
        onExit?(reason)
    }
}
