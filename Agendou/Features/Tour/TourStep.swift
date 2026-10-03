import Foundation

/// The tour's stops, in order: where the app goes and what the balloon says.
enum TourStep: Int, CaseIterable {
    case nextShift, dayStrip, category, addCategory, calendar, shiftMenu, addExtra, reminder

    var tab: AppTab {
        switch self {
        case .nextShift, .dayStrip: .home
        case .category, .addCategory: .categories
        case .calendar, .shiftMenu, .addExtra: .calendar
        case .reminder: .settings
        }
    }

    /// Steps 6 and 7 happen in the day sheet, which the tour opens itself.
    var needsDaySheet: Bool {
        self == .shiftMenu || self == .addExtra
    }

    /// Toolbar buttons report no usable frame to SwiftUI, so the tour finds them in UIKit by this
    /// accessibility identifier instead of through `.tourAnchor`.
    var barItemIdentifier: String? {
        self == .addCategory ? "categories.add" : nil
    }

    var text: LocalizedStringResource {
        switch self {
        case .nextShift: "Ao abrir o app, você vê o próximo plantão e quanto falta."
        case .dayStrip: "Os próximos dias e as horas do mês. Toque num dia para ver os detalhes."
        case .category: "Cada lugar onde você trabalha vira uma categoria, com a escala (12x36, 24x48…)."
        case .addCategory: "Crie uma categoria aqui. Sem escala fixa? Crie sem escala e marque os dias à mão."
        case .calendar: "O calendário se preenche sozinho, com a cor de cada categoria."
        case .shiftMenu: "Edite o horário, cancele ou exclua um plantão."
        case .addExtra: "Marque um plantão avulso, fora da escala."
        case .reminder: "Receba um aviso no dia do plantão, no horário que preferir."
        }
    }
}
