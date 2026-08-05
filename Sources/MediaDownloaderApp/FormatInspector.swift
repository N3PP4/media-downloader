import Foundation
import MediaDownloaderCore

final class FormatInspector {
    private let outputQueue = DispatchQueue(label: "app.media-downloader.format-inspector")
    private var process: Process?
    private var inspectionID = UUID()
    private var stdoutData = Data()
    private var stderrData = Data()

    func inspect(
        url: URL,
        executableURL: URL,
        environment: [String: String],
        completion: @escaping (Result<FormatAvailability, Error>) -> Void
    ) throws {
        cancel()
        let currentID = UUID()
        inspectionID = currentID
        stdoutData = Data()
        stderrData = Data()

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        self.process = process

        process.executableURL = executableURL
        process.arguments = [
            "--ignore-config",
            "--no-update",
            "--skip-download",
            "--no-playlist",
            "--dump-single-json",
            url.absoluteString
        ]
        process.environment = environment
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.outputQueue.async { self?.stdoutData.append(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.outputQueue.async { self?.stderrData.append(data) }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            guard let self else { return }
            self.outputQueue.async {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                self.stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                self.stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                guard self.inspectionID == currentID else { return }
                self.process = nil

                let result: Result<FormatAvailability, Error>
                if finishedProcess.terminationStatus == 0 {
                    result = Result { try FormatAvailabilityParser.parse(self.stdoutData) }
                } else {
                    let message = String(data: self.stderrData, encoding: .utf8) ?? "Format inspection failed"
                    result = .failure(NSError(
                        domain: "MediaDownloader.FormatInspector",
                        code: Int(finishedProcess.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: message]
                    ))
                }

                DispatchQueue.main.async { completion(result) }
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            self.process = nil
            throw error
        }
    }

    func cancel() {
        inspectionID = UUID()
        process?.terminate()
        process = nil
    }
}
