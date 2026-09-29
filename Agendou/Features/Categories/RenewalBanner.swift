import AgendouCore
import AgendouStore
import SwiftUI

/// A schedule whose period ends within a week or has ended, with a way to renew it.
struct RenewalBanner: View {
    let schedule: CategorySchedule
    @Environment(AgendaStore.self) private var store
    @State private var renewing = false

    var body: some View {
        let name = schedule.category?.name ?? ""
        let end = schedule.repeatsUntil ?? .distantFuture
        let lastDay = Formatting.shortDay(Formatting.lastDay(ofPeriodEndingAt: end))
        let ended = end <= .now
        Button {
            renewing = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: ended ? "exclamationmark.circle.fill" : "clock.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(schedule.category?.color ?? .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                    Text(ended ? "Escala terminou em \(lastDay)" : "Escala termina em \(lastDay)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
                Spacer()
                Text("Renovar")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("renewal.\(name)")
        .sheet(isPresented: $renewing) { RenewForm(schedule: schedule) }
    }
}
