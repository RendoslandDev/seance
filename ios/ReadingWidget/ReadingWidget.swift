import WidgetKit
import SwiftUI

// Must match WidgetService.appGroupId in lib/services/widget_service.dart and
// the App Group enabled on BOTH the Runner app and this widget extension.
private let appGroupId = "group.com.example.seance"

struct ReadingEntry: TimelineEntry {
    let date: Date
    let title: String
    let excerpt: String
    let meta: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(
            date: Date(),
            title: "This week's reading",
            excerpt: "Open séance to begin your weekly reading.",
            meta: "SÉANCE"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        let entry = readEntry()
        // Refresh roughly every 6h; the app also pushes fresh data on launch.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> ReadingEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return ReadingEntry(
            date: Date(),
            title: defaults?.string(forKey: "reading_title") ?? "This week's reading",
            excerpt: defaults?.string(forKey: "reading_excerpt")
                ?? "Open séance to begin your weekly reading.",
            meta: defaults?.string(forKey: "reading_meta") ?? "SÉANCE"
        )
    }
}

struct ReadingWidgetEntryView: View {
    var entry: Provider.Entry

    // séance palette
    private let ink = Color(white: 0.93)            // #EDEAE3
    private let surface = Color(red: 0.106, green: 0.102, blue: 0.094) // #1B1A18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.meta)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(ink.opacity(0.55))
            Text(entry.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ink)
                .lineLimit(2)
            Text(entry.excerpt)
                .font(.system(size: 13))
                .foregroundColor(ink.opacity(0.6))
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(surface)
    }
}

extension View {
    /// iOS 17 requires `containerBackground`; older versions use a plain background.
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            background(color)
        }
    }
}

@main
struct ReadingWidget: Widget {
    let kind: String = "ReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReadingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weekly reading")
        .description("This week's séance reading at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
