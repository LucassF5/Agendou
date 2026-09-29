import SwiftUI

struct CalendarScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Em construção", systemImage: "calendar")
                .navigationTitle("Calendário")
        }
    }
}

#Preview {
    CalendarScreen()
}
