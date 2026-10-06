import AgendouCore
import AgendouStore
import SwiftUI
import UIKit

/// The month grid: native `UICalendarView` (decorations, gestures and VoiceOver come for free), in the
/// workplace calendar. A dot marks each category with a shift **starting** on that day.
struct MonthCalendarView: UIViewRepresentable {
    enum Selection {
        /// Tapping a day reports it and leaves nothing selected.
        case single((CivilDate) -> Void)
        /// Tapping a day adds it to the set or takes it out.
        case multiple(Binding<Set<CivilDate>>)
    }

    @Binding var visibleMonth: CivilMonth
    /// Colors of the categories with a shift starting on each day, in display order.
    var dots: [CivilDate: [Color]]
    var selection: Selection

    init(visibleMonth: Binding<CivilMonth>, dots: [CivilDate: [Color]], onSelect: @escaping (CivilDate) -> Void) {
        _visibleMonth = visibleMonth
        self.dots = dots
        selection = .single(onSelect)
    }

    init(visibleMonth: Binding<CivilMonth>, dots: [CivilDate: [Color]], selectedDays: Binding<Set<CivilDate>>) {
        _visibleMonth = visibleMonth
        self.dots = dots
        selection = .multiple(selectedDays)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = CivilCalendar.calendar
        view.timeZone = CivilCalendar.timeZone
        view.locale = Formatting.locale
        view.delegate = context.coordinator
        switch selection {
        case .single:
            view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        case .multiple(let days):
            let behavior = UICalendarSelectionMultiDate(delegate: context.coordinator)
            behavior.selectedDates = days.wrappedValue.map(components(of:))
            view.selectionBehavior = behavior
        }
        view.visibleDateComponents = components(of: visibleMonth)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if CivilMonth(components: view.visibleDateComponents) != visibleMonth {
            view.setVisibleDateComponents(components(of: visibleMonth), animated: true)
        }
        if coordinator.shownDots != dots {
            let days = Set(coordinator.shownDots.keys).union(dots.keys)
            coordinator.shownDots = dots
            view.reloadDecorations(
                forDateComponents: days.map { DateComponents(year: $0.year, month: $0.month, day: $0.day) },
                animated: false)
        }
        if case .multiple(let days) = selection, let behavior = view.selectionBehavior as? UICalendarSelectionMultiDate,
            Set(behavior.selectedDates.compactMap(CivilDate.init(components:))) != days.wrappedValue
        {
            behavior.setSelectedDates(days.wrappedValue.map(components(of:)), animated: false)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 375
        let size = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        return CGSize(width: width, height: size.height)
    }

    private func components(of month: CivilMonth) -> DateComponents {
        DateComponents(calendar: CivilCalendar.calendar, year: month.year, month: month.month, day: 1)
    }

    private func components(of day: CivilDate) -> DateComponents {
        DateComponents(calendar: CivilCalendar.calendar, year: day.year, month: day.month, day: day.day)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate,
        UICalendarSelectionMultiDateDelegate
    {
        var parent: MonthCalendarView
        var shownDots: [CivilDate: [Color]] = [:]

        init(parent: MonthCalendarView) {
            self.parent = parent
            shownDots = parent.dots
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents)
            -> UICalendarView.Decoration?
        {
            guard let date = CivilDate(components: dateComponents), let colors = shownDots[date], !colors.isEmpty
            else { return nil }
            if colors.count == 1 {
                return .default(color: UIColor(colors[0]), size: .large)
            }
            let uiColors = colors.prefix(3).map { UIColor($0) }
            return .customView { DotsView(colors: uiColors) }
        }

        func calendarView(
            _ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents
        ) {
            if let month = CivilMonth(components: calendarView.visibleDateComponents), month != parent.visibleMonth {
                parent.visibleMonth = month
            }
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            // Deselect right away so tapping the same day again reopens it.
            selection.setSelected(nil, animated: false)
            if case .single(let onSelect) = parent.selection, let dateComponents,
                let date = CivilDate(components: dateComponents)
            {
                onSelect(date)
            }
        }

        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents)
        {
            if case .multiple(let days) = parent.selection, let date = CivilDate(components: dateComponents) {
                days.wrappedValue.insert(date)
            }
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents
        ) {
            if case .multiple(let days) = parent.selection, let date = CivilDate(components: dateComponents) {
                days.wrappedValue.remove(date)
            }
        }
    }
}

/// Up to three small dots side by side, for days with shifts of several categories.
private final class DotsView: UIStackView {
    init(colors: [UIColor]) {
        // UICalendarView keeps a custom decoration at the frame it is created with and never sizes it, so
        // the view must start at its final size. With `.zero` the dots were laid out in nothing and days
        // with shifts of two or more categories showed no dot at all.
        let count = CGFloat(colors.count)
        super.init(frame: CGRect(x: 0, y: 0, width: count * 6 + (count - 1) * 2, height: 6))
        axis = .horizontal
        spacing = 2
        for color in colors {
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6), dot.heightAnchor.constraint(equalToConstant: 6),
            ])
            addArrangedSubview(dot)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CivilDate {
    init?(components: DateComponents) {
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        self.init(year: year, month: month, day: day)
    }
}

extension CivilMonth {
    init?(components: DateComponents) {
        guard let year = components.year, let month = components.month else { return nil }
        self.init(year: year, month: month)
    }
}

extension AgendaStore {
    /// One dot per category with a shift starting on the day, in the order the shifts start.
    func dayDots(in month: CivilMonth) -> [CivilDate: [Color]] {
        let expansion = expand(in: CivilCalendar.interval(of: month))
        var dots: [CivilDate: [Color]] = [:]
        var seen: [CivilDate: Set<UUID>] = [:]
        for occurrence in expansion.occurrences {
            let day = CivilCalendar.date(containing: occurrence.startsAt)
            guard seen[day, default: []].insert(occurrence.categoryID).inserted else { continue }
            dots[day, default: []].append(category(id: occurrence.categoryID)?.color ?? .gray)
        }
        return dots
    }
}
