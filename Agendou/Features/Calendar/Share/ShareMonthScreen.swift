import AgendouCore
import AgendouStore
import SwiftUI
import UIKit

/// "Enviar plantões": choose the places, see the picture and the text, and send either one through the
/// share sheet. Day notes and hours never go.
struct ShareMonthScreen: View {
    let month: CivilMonth
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Places the user unchecked; everything else goes.
    @State private var excluded: Set<UUID> = []

    var body: some View {
        let occurrences = store.expand(in: CivilCalendar.interval(of: month)).occurrences
        let names = categoryNames(occurrences)
        let available = MonthShare(month: month, occurrences: occurrences, names: names)
        let share = MonthShare(
            month: month, occurrences: occurrences, names: names,
            including: Set(names.keys).subtracting(excluded))
        let colors = categoryColors(names.keys)
        let image = share.totalCount > 0 ? MonthShareImage.render(share, colors: colors) : nil
        let text = MonthShareText.make(share)
        NavigationStack {
            Form {
                if !available.categories.isEmpty {
                    Section {
                        ForEach(available.categories) { category in
                            toggle(category, color: colors[category.id] ?? .gray)
                        }
                    } header: {
                        Text("Locais")
                    } footer: {
                        Text("Desmarque um local para tirá-lo da imagem e do texto.")
                    }
                }
                if share.totalCount == 0 {
                    Section {
                        Text("Nenhum plantão para enviar")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("share.empty")
                    }
                } else {
                    if let image {
                        Section("Imagem") {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel(Text("Prévia da imagem"))
                                .accessibilityIdentifier("share.imagePreview")
                        }
                    }
                    Section("Texto") {
                        Text(text)
                            .font(.footnote)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("share.textPreview")
                    }
                }
            }
            .navigationTitle("Enviar plantões")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                        .accessibilityIdentifier("share.close")
                }
            }
            .safeAreaInset(edge: .bottom) {
                sendButtons(image: image, text: text, isEmpty: share.totalCount == 0)
            }
        }
    }

    private var title: String {
        String(localized: "Plantões de \(Formatting.monthYear(month))")
    }

    private func toggle(_ category: MonthShare.Category, color: Color) -> some View {
        Toggle(
            isOn: Binding(
                get: { !excluded.contains(category.id) },
                set: { included in
                    if included { excluded.remove(category.id) } else { excluded.insert(category.id) }
                })
        ) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                    Text(Formatting.shiftCount(category.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("share.category.\(category.name)")
    }

    private func sendButtons(image: UIImage?, text: String, isEmpty: Bool) -> some View {
        HStack(spacing: 12) {
            if let image {
                ShareLink(item: Image(uiImage: image), preview: SharePreview(title, image: Image(uiImage: image))) {
                    Label("Enviar imagem", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("share.sendImage")
            } else {
                Button {
                } label: {
                    Label("Enviar imagem", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .disabled(true)
                .accessibilityIdentifier("share.sendImage")
            }
            ShareLink(item: text, preview: SharePreview(title)) {
                Label("Enviar texto", systemImage: "text.alignleft")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isEmpty)
            .accessibilityIdentifier("share.sendText")
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(.bar)
    }

    private func categoryNames(_ occurrences: [Occurrence]) -> [UUID: String] {
        var names: [UUID: String] = [:]
        for id in Set(occurrences.map(\.categoryID)) {
            if let category = store.category(id: id) { names[id] = category.name }
        }
        return names
    }

    private func categoryColors(_ ids: some Sequence<UUID>) -> [UUID: Color] {
        var colors: [UUID: Color] = [:]
        for id in ids {
            colors[id] = store.category(id: id)?.color ?? .gray
        }
        return colors
    }
}
