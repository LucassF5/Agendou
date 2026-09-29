import AgendouStore
import SwiftUI

/// New category (optionally with its first schedule), or name and color of an existing one.
struct CategoryForm: View {
    enum Mode {
        case create
        case edit(ShiftCategory)
    }

    let mode: Mode
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var color = CategoryColor.teal
    @State private var hasSchedule = true
    @State private var draft = ScheduleDraft()
    @State private var anchor = DefaultTimes.nextShiftStart(after: .now)
    @State private var startsAt = DefaultTimes.nextShiftStart(after: .now)
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
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
                    Text("Um vínculo: o lugar e o tipo de plantão.")
                }
                Section("Cor") {
                    ColorPalettePicker(selection: $color)
                }
                if isCreating {
                    Section {
                        Toggle("Tem escala fixa", isOn: $hasSchedule)
                    } footer: {
                        Text("Sem escala, a categoria serve para plantões avulsos.")
                    }
                    if hasSchedule {
                        ScheduleFields(draft: $draft)
                        FirstScheduleDates(anchor: $anchor, startsAt: $startsAt)
                    }
                }
            }
            .navigationTitle(isCreating ? "Nova categoria" : "Editar categoria")
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
                if hasSchedule {
                    do {
                        try store.startFirstSchedule(
                            for: category, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds,
                            anchorAt: anchor, startsAt: startsAt)
                    } catch {
                        try? store.deletePermanently(category)
                        throw error
                    }
                }
            case .edit(let category):
                try store.updateCategory(category, name: name, color: color)
            }
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}

/// "Quando começa seu próximo plantão?" and "Desde quando?", the second prefilled with the first and never
/// after it.
struct FirstScheduleDates: View {
    @Binding var anchor: Date
    @Binding var startsAt: Date
    @State private var startsAtFollowsAnchor = true

    var body: some View {
        Section {
            DatePicker("Quando começa seu próximo plantão?", selection: $anchor)
                .accessibilityIdentifier("schedule.anchor")
        }
        Section {
            DatePicker("Desde quando você trabalha nessa escala?", selection: $startsAt, in: ...anchor)
                .accessibilityIdentifier("schedule.startsAt")
        } footer: {
            Text("Recuar a data preenche o passado no calendário com essa escala.")
        }
        .onChange(of: anchor) {
            if startsAtFollowsAnchor || startsAt > anchor { startsAt = anchor }
        }
        .onChange(of: startsAt) {
            startsAtFollowsAnchor = startsAt == anchor
        }
    }
}

#Preview {
    CategoryForm(mode: .create)
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}
