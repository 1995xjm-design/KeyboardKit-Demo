import Foundation
import SwiftUI
import UIKit

/// Settings log viewer for the gateway cache log
/// (Caches/openclaw-gateway.log, written by GatewayDiagnostics).
@MainActor
struct SettingsLogView: View {
    private struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: String
        let message: String
    }

    private struct ShareItem: Identifiable {
        let id = UUID()
        let fileURL: URL
    }

    private static var logFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("openclaw-gateway.log")
    }

    @State private var entries: [LogEntry] = []
    @State private var isLoading = false
    @State private var shareItem: ShareItem?
    @State private var showsShareError = false

    var body: some View {
        List {
            if self.entries.isEmpty {
                Text(String(localized: "No log entries yet."))
                    .font(OpenClawType.subhead)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        if !entry.timestamp.isEmpty {
                            Text(entry.timestamp)
                                .font(OpenClawType.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .font(OpenClawType.callout)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(String(localized: "Gateway Log"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(String(localized: "Refresh"))
                .disabled(self.isLoading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.copyAll()
                } label: {
                    Text(String(localized: "Copy All"))
                        .font(OpenClawType.subheadSemiBold)
                }
                .disabled(self.entries.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.share()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(String(localized: "Share"))
                .disabled(self.entries.isEmpty)
            }
        }
        .sheet(item: self.$shareItem) { item in
            ChatTranscriptShareSheet(fileURL: item.fileURL)
        }
        .alert(String(localized: "Could not share this log."), isPresented: self.$showsShareError) {
            Button(String(localized: "OK"), role: .cancel) {
                self.showsShareError = false
            }
        }
        .task {
            self.reload()
        }
    }

    private func copyAll() {
        UIPasteboard.general.string = self.rawLogText()
    }

    private func share() {
        guard !self.entries.isEmpty else { return }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenClawGatewayLogs", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent(Self.shareFilename, isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try self.rawLogText().write(to: fileURL, atomically: true, encoding: .utf8)
            self.shareItem = ShareItem(fileURL: fileURL)
        } catch {
            self.showsShareError = true
        }
    }

    private func reload() {
        guard !self.isLoading else { return }
        self.isLoading = true
        let url = Self.logFileURL
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                Self.loadEntries(from: url)
            }.value
            self.entries = loaded
            self.isLoading = false
        }
    }

    private func rawLogText() -> String {
        self.entries
            .reversed()
            .map { entry in
                entry.timestamp.isEmpty ? entry.message : "[\(entry.timestamp)] \(entry.message)"
            }
            .joined(separator: "\n")
    }

    private static var shareFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "OpenClaw-Gateway-Log-\(formatter.string(from: Date())).txt"
    }

    /// Parses "[<ISO8601 timestamp>] <message>" lines and returns them newest first.
    private nonisolated static func loadEntries(from url: URL?) -> [LogEntry] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else {
            return []
        }

        var parsed: [LogEntry] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .newlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
                let open = line.index(line.startIndex, offsetBy: 1)
                let timestamp = String(line[open..<close])
                var message = line[line.index(after: close)...]
                if message.hasPrefix(" ") {
                    message = message.dropFirst()
                }
                parsed.append(LogEntry(timestamp: timestamp, message: String(message)))
            } else {
                parsed.append(LogEntry(timestamp: "", message: line))
            }
        }

        // Newest entries first.
        return Array(parsed.reversed())
    }
}
