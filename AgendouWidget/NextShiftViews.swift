import AgendouCore
import SwiftUI
import WidgetKit

/// Texts shared by the sizes.
private enum NextShiftText {
    private static let weekday = Date.FormatStyle(
        locale: Formatting.locale, calendar: CivilCalendar.calendar, timeZone: CivilCalendar.timeZone
    ).weekday(.abbreviated)

    /// "ter", without the period pt-BR puts after the abbreviation.
    static func weekdayName(_ date: Date) -> String {
        date.formatted(weekday).replacingOccurrences(of: ".", with: "")
    }

    /// "ter 29/09".
    static func day(_ shift: WidgetShift) -> String {
        "\(weekdayName(shift.start)) \(Formatting.shortDay(CivilCalendar.date(containing: shift.startsAt)))"
    }

    static func range(_ shift: WidgetShift) -> String {
        Formatting.timeRange(startsAt: shift.startsAt, endsAt: shift.endsAt)
    }
}

struct NextShiftView: View {
    let entry: NextShiftEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .environment(\.locale, Formatting.locale)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder private var content: some View {
        if let shift = entry.shift {
            switch family {
            case .accessoryCircular: CircularView(entry: entry, shift: shift)
            case .accessoryRectangular: RectangularView(entry: entry, shift: shift)
            case .systemMedium: MediumView(entry: entry, shift: shift)
            default: SmallView(entry: entry, shift: shift)
            }
        } else {
            EmptyShiftView(family: family)
        }
    }

    @ViewBuilder private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            Color.clear
        default:
            ZStack {
                Color(.systemBackground)
                (entry.shift?.color.color ?? .accentColor).opacity(0.15)
            }
        }
    }
}

/// "Termina em 3 h" or "Começa em 2 dias", kept live by the system.
private struct Countdown: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        if entry.isInProgress {
            Text("Termina em \(shift.end, style: .relative)")
        } else {
            Text("Começa em \(shift.start, style: .relative)")
        }
    }
}

private func status(_ entry: NextShiftEntry) -> LocalizedStringKey {
    entry.isInProgress ? "Em andamento" : "Próximo plantão"
}

private struct SmallView: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(status(entry))
                .font(.caption.weight(.semibold))
                .foregroundStyle(shift.color.color)
            Text(shift.categoryName)
                .font(.headline)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(NextShiftText.day(shift))
                .font(.caption)
            Text(NextShiftText.range(shift))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Countdown(entry: entry, shift: shift)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumView: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SmallView(entry: entry, shift: shift)
            VStack(alignment: .leading, spacing: 8) {
                if entry.following.isEmpty {
                    Text("Sem outros plantões à vista")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entry.following.enumerated()), id: \.offset) { _, next in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle().fill(next.color.color).frame(width: 8, height: 8)
                                Text(next.categoryName).font(.caption.weight(.semibold)).lineLimit(1)
                            }
                            Text("\(NextShiftText.day(next)) · \(Formatting.time(next.start))")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct RectangularView: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(shift.categoryName)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(NextShiftText.range(shift))
                .font(.caption)
                .monospacedDigit()
            Countdown(entry: entry, shift: shift)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CircularView: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isInProgress {
                ProgressView(timerInterval: shift.start...shift.end, countsDown: false) {
                } currentValueLabel: {
                    Text(Formatting.time(shift.end))
                        .font(.caption2)
                        .monospacedDigit()
                }
                .progressViewStyle(.circular)
            } else {
                VStack(spacing: 0) {
                    Text(NextShiftText.weekdayName(shift.start))
                        .font(.caption2)
                    Text(Formatting.time(shift.start))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct EmptyShiftView: View {
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sem plantões à frente")
                .font(.headline)
            Text("Abra o Agendou para configurar a escala.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity, maxHeight: .infinity, alignment: family == .accessoryCircular ? .center : .topLeading)
    }
}
