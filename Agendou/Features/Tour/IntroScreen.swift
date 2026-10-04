import AgendouStore
import SwiftUI

/// What the app does, before anything else on a first launch, ending on a choice: take the tour or start
/// using the app.
struct IntroScreen: View {
    let onTour: () -> Void
    let onStart: () -> Void

    @State private var page = 0
    private static let choicePage = 2

    init(onTour: @escaping () -> Void, onStart: @escaping () -> Void) {
        self.onTour = onTour
        self.onStart = onStart
        // The page dots are a UIPageControl; the default white current dot barely shows on a light background.
        UIPageControl.appearance().currentPageIndicatorTintColor = .label
        UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
    }

    private var isChoice: Bool {
        page == Self.choicePage
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                // Skips to the choice, never past it: whoever skips still learns the tour exists.
                if !isChoice {
                    Button("Pular") { withAnimation { page = Self.choicePage } }
                        .accessibilityIdentifier("intro.skip")
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal)

            TabView(selection: $page) {
                IntroPage(
                    symbol: "calendar.badge.clock", color: .teal, title: "Bem-vindo ao Agendou",
                    text: "Ele organiza seus plantões a partir da sua escala. Tudo fica só neste iPhone."
                )
                .tag(0)
                FeaturesPage()
                    .tag(1)
                IntroPage(
                    symbol: "hand.point.up.left", color: .indigo, title: "Quer conhecer o app num tour rápido?",
                    text:
                        "Mostramos onde fica cada coisa, nas telas de verdade, com dados de exemplo. Leva menos de um minuto."
                )
                .tag(Self.choicePage)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            buttons
                .padding()
        }
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 12) {
            if isChoice {
                Button("Fazer o tour", action: onTour)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("intro.tour")
                Button("Pular e começar a usar", action: onStart)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("intro.start")
            } else {
                Button("Próximo") { withAnimation { page += 1 } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("intro.next")
            }
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
}

private struct IntroPage: View {
    let symbol: String
    let color: CategoryColor
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: symbol)
                    .font(.system(size: 88))
                    .foregroundStyle(color.color)
                    .accessibilityHidden(true)
                    .padding(.top, 48)
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(text)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The app's features, one line each.
private struct FeaturesPage: View {
    private let features: [(symbol: String, color: CategoryColor, text: LocalizedStringResource)] = [
        ("calendar.badge.clock", .teal, "Escalas (12x36, 24x48…) que preenchem o calendário sozinhas"),
        ("plus.circle", .orange, "Plantões avulsos, para quem não tem escala fixa"),
        ("calendar", .indigo, "Calendário com o resumo de horas do mês"),
        ("bell", .pink, "Lembrete no dia do plantão"),
        ("square.and.arrow.up", .blue, "Compartilhar o mês como imagem ou texto"),
        ("externaldrive", .green, "Backup dos seus dados"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("O que o Agendou faz")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 48)
                    .padding(.bottom, 8)
                ForEach(features.indices, id: \.self) { index in
                    let feature = features[index]
                    HStack(spacing: 16) {
                        Image(systemName: feature.symbol)
                            .font(.title2)
                            .foregroundStyle(feature.color.color)
                            .frame(width: 36)
                            .accessibilityHidden(true)
                        Text(feature.text)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    IntroScreen(onTour: {}, onStart: {})
        .agendouEnvironment()
}
