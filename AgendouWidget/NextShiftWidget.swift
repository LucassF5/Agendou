import SwiftUI
import WidgetKit

nonisolated struct NextShiftProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextShiftEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NextShiftEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { @MainActor in
            completion(NextShiftLoader.timeline(now: .now).entries.first ?? .empty(at: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NextShiftEntry>) -> Void) {
        Task { @MainActor in
            completion(NextShiftLoader.timeline(now: .now))
        }
    }
}

struct NextShiftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextShiftWidget", provider: NextShiftProvider()) { entry in
            NextShiftView(entry: entry)
        }
        .configurationDisplayName("Próximo plantão")
        .description("Veja o plantão em andamento ou o próximo sem abrir o app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

#Preview("Pequeno", as: .systemSmall) {
    NextShiftWidget()
} timeline: {
    NextShiftEntry.sample
    NextShiftEntry.sampleInProgress
    NextShiftEntry.empty(at: .now)
    NextShiftEntry.unavailable(at: .now)
}

#Preview("Médio", as: .systemMedium) {
    NextShiftWidget()
} timeline: {
    NextShiftEntry.sample
    NextShiftEntry.sampleInProgress
    NextShiftEntry.empty(at: .now)
    NextShiftEntry.unavailable(at: .now)
}

#Preview("Retangular", as: .accessoryRectangular) {
    NextShiftWidget()
} timeline: {
    NextShiftEntry.sample
    NextShiftEntry.sampleInProgress
    NextShiftEntry.empty(at: .now)
    NextShiftEntry.unavailable(at: .now)
}

#Preview("Circular", as: .accessoryCircular) {
    NextShiftWidget()
} timeline: {
    NextShiftEntry.sample
    NextShiftEntry.sampleInProgress
    NextShiftEntry.empty(at: .now)
    NextShiftEntry.unavailable(at: .now)
}
