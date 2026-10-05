import AgendouCore
import AgendouStore
import SwiftUI
import WidgetKit

nonisolated struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

nonisolated struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

struct NextShiftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextShiftWidget", provider: PlaceholderProvider()) { _ in
            Text(Formatting.time(.now))
                .foregroundStyle(CategoryColor.teal.color)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Próximo plantão")
        .description("Veja o plantão em andamento ou o próximo sem abrir o app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
