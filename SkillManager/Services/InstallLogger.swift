import Foundation

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: Level
    let message: String

    enum Level: String, Sendable {
        case info = "INFO"
        case success = "OK"
        case error = "ERROR"
        case step = "STEP"
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}

@MainActor @Observable
final class InstallLogger {
    static let shared = InstallLogger()

    var entries: [LogEntry] = []
    private let maxEntries = 500

    func log(_ message: String, level: LogEntry.Level = .info) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func step(_ message: String) {
        log(message, level: .step)
    }

    func success(_ message: String) {
        log(message, level: .success)
    }

    func error(_ message: String) {
        log(message, level: .error)
    }

    func clear() {
        entries.removeAll()
    }
}
