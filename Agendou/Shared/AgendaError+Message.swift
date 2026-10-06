import AgendouStore
import SwiftUI

extension AgendaError {
    var message: String {
        switch self {
        case .emptyName: String(localized: "Dê um nome ao local.")
        case .categoryArchived: String(localized: "Este local está arquivado.")
        case .invalidDuration: String(localized: "A duração precisa ser maior que zero.")
        case .startsAfterAnchor: String(localized: "“Desde quando” não pode ser depois do próximo plantão.")
        case .categoryAlreadyHasSchedule: String(localized: "Este local já tem escala. Use “Mudei de escala”.")
        case .noOpenSchedule: String(localized: "Este local não tem escala em vigor.")
        case .anchorInPast: String(localized: "A escala nova não pode começar no passado.")
        case .anchorNotAfterCurrentStart:
            String(localized: "A escala nova precisa começar depois do início da escala atual.")
        case .scheduleLocked:
            String(
                localized:
                    "Essa escala não pode mais ser alterada: um plantão dela já começou e ela tem mais de 24 horas. Use “Mudei de escala”."
            )
        case .categoryHasHistory:
            String(localized: "O local tem histórico e não pode ser excluído. Arquive em vez disso.")
        case .duplicateOverride: String(localized: "Já existe um plantão desse local nesse horário.")
        case .notScheduled: String(localized: "Só plantões da escala podem ser cancelados.")
        case .notAdjusted: String(localized: "Esse plantão não foi ajustado.")
        case .notFound: String(localized: "Não encontrado.")
        case .invalidRepeatEnd:
            String(localized: "O prazo precisa cobrir o primeiro plantão e, ao renovar, passar do prazo atual.")
        }
    }
}

/// Message for any error thrown by the store.
func userMessage(for error: any Error) -> String {
    (error as? AgendaError)?.message ?? error.localizedDescription
}

extension View {
    /// Shows `message` in an alert while it is not `nil`.
    func errorAlert(_ message: Binding<String?>, title: LocalizedStringKey = "Não foi possível salvar") -> some View {
        alert(
            title,
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
