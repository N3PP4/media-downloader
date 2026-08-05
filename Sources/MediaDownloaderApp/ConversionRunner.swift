import Foundation

final class ConversionRunner {
    enum VideoEncoder: String {
        case videoToolbox = "hevc_videotoolbox"
        case software = "libx265"
    }

    struct Callbacks {
        var onProgress: (Double) -> Void
        var onRawLine: (String) -> Void
        var onCompletion: (_ exitCode: Int32, _ wasCancelled: Bool, _ recentLines: [String]) -> Void
    }

    private let outputQueue = DispatchQueue(label: "app.media-downloader.conversion-output")
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = ""
    private var recentLines: [String] = []
    private var callbacks: Callbacks?
    private var cancellationRequested = false
    private var duration: TimeInterval?

    var isRunning: Bool { process?.isRunning == true }

    func start(
        executableURL: URL,
        inputURL: URL,
        outputURL: URL,
        duration: TimeInterval?,
        encoder: VideoEncoder = .videoToolbox,
        callbacks: Callbacks
    ) throws {
        guard !isRunning else { return }

        let process = Process()
        let pipe = Pipe()
        self.process = process
        self.pipe = pipe
        self.callbacks = callbacks
        self.duration = duration
        cancellationRequested = false
        buffer = ""
        recentLines = []

        process.executableURL = executableURL
        process.arguments = Self.arguments(
            inputURL: inputURL,
            outputURL: outputURL,
            encoder: encoder
        )
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.outputQueue.async { self?.consume(data) }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            guard let self else { return }
            self.outputQueue.async {
                self.pipe?.fileHandleForReading.readabilityHandler = nil
                if let remaining = self.pipe?.fileHandleForReading.readDataToEndOfFile(), !remaining.isEmpty {
                    self.consume(remaining)
                }
                self.flushBuffer()
                let wasCancelled = self.cancellationRequested
                let lines = self.recentLines
                let completion = self.callbacks?.onCompletion
                self.callbacks = nil
                self.process = nil
                self.pipe = nil
                DispatchQueue.main.async {
                    completion?(finishedProcess.terminationStatus, wasCancelled, lines)
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

    static func arguments(inputURL: URL, outputURL: URL, encoder: VideoEncoder) -> [String] {
        var arguments = [
            "-hide_banner",
            "-y",
            "-i", inputURL.path,
            "-map", "0:v:0",
            "-map", "0:a:0?",
            "-map_metadata", "0",
            "-c:v", encoder.rawValue
        ]

        switch encoder {
        case .videoToolbox:
            arguments.append(contentsOf: [
                "-allow_sw", "1",
                "-q:v", "65"
            ])
        case .software:
            arguments.append(contentsOf: [
                "-preset", "fast",
                "-crf", "23",
                "-pix_fmt", "yuv420p"
            ])
        }

        arguments.append(contentsOf: [
            "-tag:v", "hvc1",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "-progress", "pipe:1",
            "-nostats",
            outputURL.path
        ])
        return arguments
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
        for line in parts.dropLast() { consume(line: line) }
    }

    private func flushBuffer() {
        if !buffer.isEmpty {
            consume(line: buffer)
            buffer = ""
        }
    }

    private func consume(line: String) {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        recentLines.append(cleaned)
        if recentLines.count > 60 {
            recentLines.removeFirst(recentLines.count - 60)
        }

        if cleaned.hasPrefix("out_time_us="),
           let duration,
           duration > 0,
           let microseconds = Double(cleaned.dropFirst("out_time_us=".count)) {
            let value = min(max((microseconds / 1_000_000) / duration, 0), 1)
            let progressCallback = callbacks?.onProgress
            DispatchQueue.main.async { progressCallback?(value) }
        }

        if cleaned.hasPrefix("progress=") { return }
        let rawLineCallback = callbacks?.onRawLine
        DispatchQueue.main.async { rawLineCallback?(cleaned) }
    }
}
