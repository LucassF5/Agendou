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
}
