import AgendouStore
import SwiftUI

/// The first-launch tour: six pages from setting up a category to the reminder.
struct TutorialScreen: View {
    /// With a schedule the last button only closes; without one it leads to the category form.
    let hasSchedule: Bool
    let onClose: (_ setUpSchedule: Bool) -> Void

    @State private var page = 0

    init(hasSchedule: Bool, onClose: @escaping (_ setUpSchedule: Bool) -> Void) {
        self.hasSchedule = hasSchedule
        self.onClose = onClose
        // The page dots are a UIPageControl; the default white current dot barely shows on a light background.
        UIPageControl.appearance().currentPageIndicatorTintColor = .label
        UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
    }

    private var isLast: Bool {
        page == TutorialPage.all.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !(isLast && hasSchedule) {
                    Button("Pular") { onClose(false) }
                        .accessibilityIdentifier("tutorial.skip")
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal)

            TabView(selection: $page) {
                ForEach(TutorialPage.all.indices, id: \.self) { index in
                    TutorialPageView(page: TutorialPage.all[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            bottomButton
                .padding()
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        Group {
            if !isLast {
                Button("Próximo") { withAnimation { page += 1 } }
                    .accessibilityIdentifier("tutorial.next")
            } else if hasSchedule {
                Button("Concluir") { onClose(false) }
                    .accessibilityIdentifier("tutorial.done")
            } else {
                Button("Configurar minha escala") { onClose(true) }
                    .accessibilityIdentifier("tutorial.setup")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
}

struct TutorialPage {
    let symbol: String
    let color: CategoryColor
    let title: LocalizedStringResource
    let body: LocalizedStringResource

    static let all = [
        TutorialPage(
            symbol: "calendar.badge.clock", color: .teal, title: "Seus plantões, organizados",
            body: "O Agendou monta o calendário a partir da sua escala. Tudo fica só neste iPhone."),
        TutorialPage(
            symbol: "square.stack", color: .blue, title: "Onde você trabalha",
            body:
                "Crie uma categoria para cada lugar, com a escala (12x36, 24x48…) e o primeiro plantão. Sem escala fixa? Crie a categoria e marque os dias à mão."
        ),
        TutorialPage(
            symbol: "calendar", color: .indigo, title: "O calendário se preenche",
            body: "Cada categoria tem sua cor. Toque num dia para ver os plantões e anotar o que aconteceu."),
        TutorialPage(
            symbol: "ellipsis.circle", color: .orange, title: "Mudou alguma coisa?",
            body:
                "No dia, “Adicionar extra” marca um plantão avulso. O botão … edita o horário, cancela ou exclui um plantão."
        ),
        TutorialPage(
            symbol: "house", color: .green, title: "Tudo no Início",
            body: "O próximo plantão, os próximos dias e as horas do mês, assim que você abre o app."),
        TutorialPage(
            symbol: "bell", color: .pink, title: "Lembrete no dia",
            body: "Em Ajustes, ative um aviso no horário que preferir, só nos dias de plantão."),
    ]
}

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: page.symbol)
                    .font(.system(size: 88))
                    .foregroundStyle(page.color.color)
                    .accessibilityHidden(true)
                    .padding(.top, 48)
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    TutorialScreen(hasSchedule: false) { _ in }
        .agendouEnvironment()
}
