import AgendouStore
import SwiftUI

extension CategoryColor {
    /// System colors adapt to light and dark mode on their own.
    var color: Color {
        switch self {
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .brown: .brown
        case .green: .green
        case .mint: .mint
        }
    }

    var name: String {
        switch self {
        case .teal: String(localized: "Verde-azulado")
        case .blue: String(localized: "Azul")
        case .indigo: String(localized: "Índigo")
        case .purple: String(localized: "Roxo")
        case .pink: String(localized: "Rosa")
        case .red: String(localized: "Vermelho")
        case .orange: String(localized: "Laranja")
        case .brown: String(localized: "Marrom")
        case .green: String(localized: "Verde")
        case .mint: String(localized: "Menta")
        }
    }
}

extension ShiftCategory {
    var color: Color {
        CategoryColor(key: colorKey).color
    }
}

/// The fixed palette as a grid of swatches.
struct ColorPalettePicker: View {
    @Binding var selection: CategoryColor

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(CategoryColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 36, height: 36)
                        .overlay {
                            if color == selection {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.name)
                .accessibilityAddTraits(color == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
