import Foundation

/// The tour's stops, in order: where the app goes and what the balloon says.
enum TourStep: Int, CaseIterable {
    case nextShift, dayStrip, category, addCategory, calendar, addShifts, shiftMenu, addExtra, reminder

    var tab: AppTab {
        switch self {
        case .nextShift, .dayStrip: .home
        case .category, .addCategory: .schedules
        case .calendar, .addShifts, .shiftMenu, .addExtra: .calendar
        case .reminder: .settings
        }
    }

    /// Steps 7 and 8 happen in the day sheet, which the tour opens itself.
    var needsDaySheet: Bool {
        self == .shiftMenu || self == .addExtra
    }

    /// Toolbar buttons report no usable frame to SwiftUI, so the tour finds them in UIKit by this
    /// accessibility identifier instead of through `.tourAnchor`.
    var barItemIdentifier: String? {
        switch self {
        case .addCategory: "categories.add"
        case .addShifts: "calendar.addShifts"
        default: nil
        }
    }

    var text: LocalizedStringResource {
        switch self {
        case .nextShift: "Ao abrir o app, você vê o próximo plantão e quanto falta."
        case .dayStrip: "Os próximos dias e as horas do mês. Toque num dia para ver os detalhes."
        case .category:
            "Cada lugar onde você trabalha, com a escala (12x36, 24x48…). Toque para renovar ou mudar a escala."
        case .addCategory:
            "Crie um local aqui. Com escala fixa, você define a escala logo depois; sem escala, marca os dias à mão."
        case .calendar: "O calendário se preenche sozinho, com a cor de cada local."
        case .addShifts: "No +, marque vários dias de plantão de uma vez ou mude a escala de um local."
        case .shiftMenu: "Edite o horário, cancele ou exclua um plantão."
        case .addExtra: "Marque um plantão avulso só neste dia."
        case .reminder: "Receba um aviso no dia do plantão, no horário que preferir."
        }
    }
}
