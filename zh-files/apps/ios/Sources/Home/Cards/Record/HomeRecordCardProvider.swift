import SwiftUI

/// 「记录」卡 Provider（D-record）：
/// destination → 记录主页；quickActions → 语音速记 / 手记 / 会议记录。
enum HomeRecordCardProvider: HomeCardDestinationProviding {
    static var supportedKinds: [HomeCardKind] { [.record] }

    static func destination(for kind: HomeCardKind) -> AnyView? {
        guard kind == .record else { return nil }
        return AnyView(RecordHomeView())
    }

    static func quickActions(for kind: HomeCardKind) -> [HomeCardQuickAction]? {
        guard kind == .record else { return nil }
        return [
            HomeCardQuickAction(
                id: "record.voiceNotes",
                title: String(localized: "Record.VoiceNotes"),
                icon: "waveform",
                destination: { AnyView(VoiceNotesScreen()) }
            ),
            HomeCardQuickAction(
                id: "record.writing",
                title: String(localized: "Record.Writing"),
                icon: "square.and.pencil",
                destination: { AnyView(WritingScreen()) }
            ),
            HomeCardQuickAction(
                id: "record.meeting",
                title: String(localized: "Record.Meeting"),
                icon: "person.2.fill",
                destination: { AnyView(MeetingScreen()) }
            )
        ]
    }
}