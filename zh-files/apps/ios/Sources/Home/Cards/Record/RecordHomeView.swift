import SwiftUI

/// 「记录」主页：语音速记 / 手记 / 会议记录 三页分段切换。
struct RecordHomeView: View {
    enum RecordTab: String, CaseIterable, Identifiable {
        case voiceNotes
        case writing
        case meeting

        var id: String { rawValue }
    }

    @State private var selection: RecordTab = .voiceNotes

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Record.Section"), selection: $selection) {
                Text(String(localized: "Record.VoiceNotes")).tag(RecordTab.voiceNotes)
                Text(String(localized: "Record.Writing")).tag(RecordTab.writing)
                Text(String(localized: "Record.Meeting")).tag(RecordTab.meeting)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, OpenClawProMetric.pagePadding)
            .padding(.vertical, 8)

            switch selection {
            case .voiceNotes:
                VoiceNotesScreen()
            case .writing:
                WritingScreen()
            case .meeting:
                MeetingScreen()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: "Record.Card"))
        .navigationBarTitleDisplayMode(.inline)
    }
}