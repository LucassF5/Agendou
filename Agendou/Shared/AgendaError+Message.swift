import AgendouStore
import SwiftUI

extension AgendaError {
    var message: String {
        switch self {
        case .emptyName: String(localized: "Dê um nome à categoria.")
        case .categoryArchived: String(localized: "Esta categoria está arquivada.")
        case .invalidDuration: String(localized: "A duração precisa ser maior que zero.")
        case .startsAfterAnchor: String(localized: "“Desde quando” não pode ser depois do próximo plantão.")
        case .categoryAlreadyHasSchedule: String(localized: "Esta categoria já tem escala. Use “Mudei de escala”.")
        case .noOpenSchedule: String(localized: "Esta categoria não tem escala em vigor.")
        case .anchorInPast: String(localized: "A escala nova não pode começar no passado.")
        case .anchorNotAfterCurrentStart:
            String(localized: "A escala nova precisa começar depois do início da escala atual.")
        case .scheduleLocked:
            String(
                localized:
                    "Essa escala não pode mais ser alterada: um plantão dela já começou e ela tem mais de 24 horas. Use “Mudei de escala”."
            )
        case .categoryHasHistory:
            String(localized: "A categoria tem histórico e não pode ser excluída. Arquive em vez disso.")
        case .duplicateOverride: String(localized: "Já existe um plantão dessa categoria nesse horário.")
        case .notScheduled: String(localized: "Só plantões da escala podem ser cancelados.")
        case .notAdjusted: String(localized: "Esse plantão não foi ajustado.")
        case .notFound: String(localized: "Não encontrado.")
        }
    }
}

/// Message for any error thrown by the store.
func userMessage(for error: any Error) -> String {
    (error as? AgendaError)?.message ?? error.localizedDescription
}

extension View {
    /// Shows `message` in an alert while it is not `nil`.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Não foi possível salvar",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
