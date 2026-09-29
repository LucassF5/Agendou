import AgendouCore
import SwiftUI
import UIKit

/// The month as a picture: each day with a shift gets a chip in its place's color with the short label
/// and the start time, and the legend below names each place. Always light, whatever the phone's mode,
/// so it reads the same wherever it is opened.
struct MonthShareImage: View {
    let share: MonthShare
    let colors: [UUID: Color]

    private let columnWidth: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plantões · \(Formatting.monthYear(share.month))")
                .font(.system(size: 20, weight: .bold))
            grid
            Divider()
            legend
            Text("Cada plantão aparece no dia em que começa.")
                .font(.system(size: 10))
                .foregroundStyle(Color.gray)
        }
        .padding(20)
        .frame(width: columnWidth * 7 + 40, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(Color.black)
    }

    /// A `Grid`, not a `LazyVGrid`: `ImageRenderer` draws only the cells a lazy grid has created, and the
    /// last week of the month came out blank.
    private var grid: some View {
        let leading = CivilCalendar.weekday(of: share.month.firstDay) - 1
        let cells: [CivilDate?] = Array(repeating: nil, count: leading) + share.month.days.map { Optional($0) }
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
        return Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Formatting.weekdayInitials, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.gray)
                        .frame(width: columnWidth, height: 18)
                }
            }
            ForEach(weeks.indices, id: \.self) { index in
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        if column < weeks[index].count, let day = weeks[index][column] {
                            cell(day)
                        } else {
                            Color.clear.frame(width: columnWidth, height: 68)
                        }
                    }
                }
            }
        }
    }

    private func cell(_ day: CivilDate) -> some View {
        let shifts = share.shifts(on: day)
        var categoryIDs: [UUID] = []
        for shift in shifts where !categoryIDs.contains(shift.categoryID) {
            categoryIDs.append(shift.categoryID)
        }
        let chips = categoryIDs.count <= 2 ? categoryIDs : [categoryIDs[0]]
        return VStack(spacing: 2) {
            Text(verbatim: "\(day.day)")
                .font(.system(size: 11, weight: shifts.isEmpty ? .regular : .semibold))
                .foregroundStyle(shifts.isEmpty ? Color.gray : Color.black)
            ForEach(chips, id: \.self) { id in
                chip(id)
            }
            if categoryIDs.count > 2 {
                Text(verbatim: "+\(categoryIDs.count - 1)")
                    .font(.system(size: 8, weight: .semibold))
            }
            if let first = shifts.first {
                Text(Formatting.hourLabel(first.startsAt))
                    .font(.system(size: 8))
                    .foregroundStyle(Color.gray)
            }
        }
        .frame(width: columnWidth, height: 64, alignment: .top)
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 0.5)
        }
    }

    private func chip(_ id: UUID) -> some View {
        Text(share.categories.first { $0.id == id }?.shortLabel ?? "")
            .font(.system(size: 9, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 3)
            .frame(maxWidth: columnWidth - 6, minHeight: 14)
            .background(colors[id] ?? .gray, in: RoundedRectangle(cornerRadius: 4))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(share.categories) { category in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    chip(category.id)
                        .frame(width: columnWidth - 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(
                            "\(Formatting.clockRange(startOfDay: category.usualStart, duration: category.usualDuration)) · \(Formatting.shiftCount(category.count))"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray)
                    }
                }
            }
        }
    }

    /// The picture at 3× (about 1,100 px wide), fixed to the light mode, pt-BR and the default text size.
    static func render(_ share: MonthShare, colors: [UUID: Color]) -> UIImage? {
        let renderer = ImageRenderer(
            content: MonthShareImage(share: share, colors: colors)
                .environment(\.colorScheme, .light)
                .environment(\.locale, Formatting.locale)
                .dynamicTypeSize(.large))
        renderer.scale = 3
        return renderer.uiImage
    }
}
