import AgendouCore
import AgendouStore
import SwiftUI

/// New category, or name and color of an existing one. The schedule comes after: a new category with a fixed
/// schedule is handed to `onCreatedWithSchedule`, and "Definir escala" follows once this form is gone.
struct CategoryForm: View {
    enum Mode {
        case create
        case edit(ShiftCategory)
    }

    let mode: Mode
    let onCreatedWithSchedule: (ShiftCategory) -> Void
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var color = CategoryColor.teal
    @State private var hasSchedule = true
    @State private var errorMessage: String?

    init(mode: Mode, onCreatedWithSchedule: @escaping (ShiftCategory) -> Void = { _ in }) {
        self.mode = mode
        self.onCreatedWithSchedule = onCreatedWithSchedule
        if case .edit(let category) = mode {
            _name = State(initialValue: category.name)
            _color = State(initialValue: CategoryColor(key: category.colorKey))
        }
    }

    private var isCreating: Bool {
        if case .create = mode { true } else { false }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $name, prompt: Text("Ex.: UTI Hospital X"))
                        .accessibilityIdentifier("category.name")
                } footer: {
                    Text("O lugar e o tipo de plantão.")
                }
                Section("Cor") {
                    ColorPalettePicker(selection: $color)
                }
                if isCreating {
                    Section {
                        Toggle("Tem escala fixa", isOn: $hasSchedule)
                            .accessibilityIdentifier("category.hasSchedule")
                    } footer: {
                        Text(
                            hasSchedule
                                ? "Depois de salvar, você define a escala."
                                : "Sem escala, o local serve para plantões avulsos.")
                    }
                }
            }
            .navigationTitle(isCreating ? "Novo local" : "Editar local")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("category.save")
                }
            }
            .errorAlert($errorMessage)
        }
    }

    private func save() {
        do {
            switch mode {
            case .create:
                let category = try store.createCategory(name: name, color: color)
                if hasSchedule { onCreatedWithSchedule(category) }
            case .edit(let category):
                try store.updateCategory(category, name: name, color: color)
            }
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}

#Preview {
    CategoryForm(mode: .create)
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}
