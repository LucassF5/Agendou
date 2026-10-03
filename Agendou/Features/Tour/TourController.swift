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
    /// Global frames reported by `.tourAnchor`. Kept even when the tour is not running, so a step finds
    /// the frame of a view that was laid out before the tour started.
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
