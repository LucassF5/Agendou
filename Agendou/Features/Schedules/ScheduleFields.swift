import SwiftUI

/// Work × rest in whole hours, with the usual presets.
struct ScheduleDraft: Equatable {
    struct Preset: Hashable {
        let workHours: Int
        let restHours: Int
    }

    static let presets = [
        Preset(workHours: 12, restHours: 36), Preset(workHours: 24, restHours: 48),
        Preset(workHours: 24, restHours: 72),
    ]

    var workHours = 12
    var restHours = 36
    var isCustom = false

    var workSeconds: Int { workHours * 3_600 }
    var restSeconds: Int { restHours * 3_600 }

    init() {}

    init(workSeconds: Int, restSeconds: Int) {
        workHours = max(1, workSeconds / 3_600)
        restHours = max(1, restSeconds / 3_600)
        isCustom = !Self.presets.contains(Preset(workHours: workHours, restHours: restHours))
    }

    func isSelected(_ preset: Preset) -> Bool {
        !isCustom && workHours == preset.workHours && restHours == preset.restHours
    }
}

struct ScheduleFields: View {
    @Binding var draft: ScheduleDraft

    var body: some View {
        Section("Escala") {
            ForEach(ScheduleDraft.presets, id: \.self) { preset in
                option("\(preset.workHours)x\(preset.restHours)", selected: draft.isSelected(preset)) {
                    draft = ScheduleDraft(workSeconds: preset.workHours * 3_600, restSeconds: preset.restHours * 3_600)
                }
                .accessibilityIdentifier("preset.\(preset.workHours)x\(preset.restHours)")
            }
            option(String(localized: "Personalizada"), selected: draft.isCustom) {
                draft.isCustom = true
            }
            .accessibilityIdentifier("preset.custom")
            if draft.isCustom {
                Stepper(value: $draft.workHours, in: 1...168) {
                    LabeledContent("Trabalho", value: "\(draft.workHours) h")
                }
                Stepper(value: $draft.restHours, in: 1...336) {
                    LabeledContent("Folga", value: "\(draft.restHours) h")
                }
            }
        }
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                // Color.primary, not .primary: inside a button .primary resolves to the tint.
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
