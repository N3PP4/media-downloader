import Foundation
import MediaDownloaderCore

final class DownloadRunner {
    struct Callbacks {
        var onEvent: (DownloadOutputEvent) -> Void
        var onRawLine: (String) -> Void
        var onCompletion: (_ exitCode: Int32, _ wasCancelled: Bool, _ recentLines: [String]) -> Void
    }

    private let outputQueue = DispatchQueue(label: "app.media-downloader.output")
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = ""
    private var recentLines: [String] = []
    private var callbacks: Callbacks?
    private var cancellationRequested = false

    var isRunning: Bool { process?.isRunning == true }

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        callbacks: Callbacks
    ) throws {
        guard !isRunning else { return }

        let process = Process()
        let pipe = Pipe()
        self.process = process
        self.pipe = pipe
        self.callbacks = callbacks
        cancellationRequested = false
        buffer = ""
        recentLines = []

        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.outputQueue.async {
                self?.consume(data)
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            guard let self else { return }
            self.outputQueue.async {
                self.flushBuffer()
                let wasCancelled = self.cancellationRequested
                let lines = self.recentLines
                self.pipe?.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.pipe = nil
                DispatchQueue.main.async {
                    self.callbacks?.onCompletion(finishedProcess.terminationStatus, wasCancelled, lines)
                    self.callbacks = nil
                }
            }
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            self.process = nil
            self.pipe = nil
            self.callbacks = nil
            throw error
        }
    }

    func cancel() {
        cancellationRequested = true
        process?.terminate()
    }

    private func consume(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk.replacingOccurrences(of: "\r", with: "\n")
        let parts = buffer.components(separatedBy: "\n")
        buffer = parts.last ?? ""
        for line in parts.dropLast() {
            consume(line: line)
        }
    }

    private func flushBuffer() {
        if !buffer.isEmpty {
            consume(line: buffer)
            buffer = ""
        }
    }

    private func consume(line: String) {
        let cleaned = OutputParser.stripANSI(line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        recentLines.append(cleaned)
        if recentLines.count > 40 {
            recentLines.removeFirst(recentLines.count - 40)
        }

        let event = OutputParser.parse(line: cleaned)
        DispatchQueue.main.async { [weak self] in
            self?.callbacks?.onRawLine(cleaned)
            if let event {
                self?.callbacks?.onEvent(event)
            }
        }
    }
}
