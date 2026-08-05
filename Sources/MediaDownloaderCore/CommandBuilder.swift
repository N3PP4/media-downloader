import Foundation

public enum CommandBuilder {
    public static func arguments(for request: DownloadRequest, ffmpegURL: URL?) -> [String] {
        var arguments = [
            "--ignore-config",
            "--newline",
            "--progress",
            "--progress-delta", "0.5",
            "--no-update",
            "--embed-metadata",
            "--print", "before_dl:__MD_ITEM__%(playlist_index)s\t%(playlist_count)s\t%(duration)s\t%(title)s",
            "--print", "before_dl:__MD_TITLE__%(title)s",
            "--print", "after_move:__MD_FILE__%(filepath)s"
        ]

        if request.allowPlaylist {
            arguments.append(contentsOf: ["--yes-playlist", "--ignore-errors"])
        } else {
            arguments.append("--no-playlist")
        }

        if let ffmpegURL {
            arguments.append(contentsOf: ["--ffmpeg-location", ffmpegURL.path])
        }

        switch request.kind {
        case .video:
            let format: String
            if let height = request.videoQuality.maximumHeight {
                format = "bv*[format_note^=\(height)p]+ba/b[format_note^=\(height)p]/bv*[height<=\(height)]+ba/b[height<=\(height)]/b"
            } else {
                format = "bv*+ba/b"
            }
            arguments.append(contentsOf: [
                "-f", format,
                "--merge-output-format", "mp4",
                "-o", "%(title)s [%(id)s] [%(resolution)s].%(ext)s"
            ])
            if !request.convertForQuickTime {
                arguments.append(contentsOf: ["-t", "mp4"])
            }
        case .mp3:
            arguments.append(contentsOf: [
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", request.mp3Quality.ytDLPValue
            ])
        }

        arguments.append(contentsOf: ["-P", request.destinationDirectory.path])
        arguments.append(request.url.absoluteString)
        return arguments
    }
}
