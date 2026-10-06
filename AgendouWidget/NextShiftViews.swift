import AgendouCore
import SwiftUI
import WidgetKit

/// Texts shared by the sizes.
private enum NextShiftText {
    private static let weekday = Date.FormatStyle(
        locale: Formatting.locale, calendar: CivilCalendar.calendar, timeZone: CivilCalendar.timeZone
    ).weekday(.abbreviated)

    private static let wideWeekday = Date.FormatStyle(
        locale: Formatting.locale, calendar: CivilCalendar.calendar, timeZone: CivilCalendar.timeZone
    ).weekday(.wide)

    /// "ter", without the period pt-BR puts after the abbreviation.
    static func weekdayName(_ date: Date) -> String {
        date.formatted(weekday).replacingOccurrences(of: ".", with: "")
    }

    /// "terça-feira", for VoiceOver.
    static func wideWeekdayName(_ date: Date) -> String {
        date.formatted(wideWeekday)
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
            switch family {
            case .accessoryCircular: CircularNoShiftView(isUnavailable: entry.isUnavailable)
            case .accessoryRectangular: RectangularNoShiftView(isUnavailable: entry.isUnavailable)
            default: NoShiftView(isUnavailable: entry.isUnavailable)
            }
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

/// "Próximo plantão" or "Em andamento" after a dot in the shift's color. The text stays in the primary
/// color: in the shift's color on its own tint it is too faint in light mode.
private struct Status: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(shift.color.color).frame(width: 8, height: 8)
            Text(entry.isInProgress ? "Em andamento" : "Próximo plantão")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct SmallView: View {
    let entry: NextShiftEntry
    let shift: WidgetShift

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Status(entry: entry, shift: shift)
            Text(shift.categoryName)
                .font(.headline)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(NextShiftText.day(shift))
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(NextShiftText.range(shift))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Countdown(entry: entry, shift: shift)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
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
                        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// What VoiceOver reads instead of the ring or the bare "ter 19:00".
    private var label: Text {
        let name = shift.categoryName
        if entry.isInProgress {
            return Text("Em andamento: \(name), termina às \(Formatting.time(shift.end))")
        }
        let weekday = NextShiftText.wideWeekdayName(shift.start)
        return Text("Próximo plantão: \(name), \(weekday) às \(Formatting.time(shift.start))")
    }
}

/// No shift to show: none ahead, or the database could not be opened (`isUnavailable`).
private struct NoShiftView: View {
    let isUnavailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isUnavailable ? "Plantões indisponíveis" : "Sem plantões à frente")
                .font(.headline)
            Text(isUnavailable ? "Desbloqueie o iPhone ou abra o Agendou." : "Abra o Agendou para configurar a escala.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// `NoShiftView` for the lock screen's rectangle: the headline may take two lines, the hint is shorter.
private struct RectangularNoShiftView: View {
    let isUnavailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(isUnavailable ? "Plantões indisponíveis" : "Sem plantões à frente")
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("Abra o Agendou")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// `NoShiftView` for the lock screen's circle: a symbol, with the headline for VoiceOver.
private struct CircularNoShiftView: View {
    let isUnavailable: Bool

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: isUnavailable ? "exclamationmark.circle" : "calendar")
                .font(.title2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isUnavailable ? Text("Plantões indisponíveis") : Text("Sem plantões à frente"))
    }
}
