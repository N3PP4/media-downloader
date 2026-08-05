#!/usr/bin/env python3
"""Offline integration test for the bundled yt-dlp and FFmpeg executables."""

from __future__ import annotations

import functools
import http.server
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import threading


def run(
    command: list[str],
    cwd: pathlib.Path | None = None,
    environment: dict[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=environment,
    )


def verify_media(ffmpeg: pathlib.Path, media_path: pathlib.Path) -> None:
    run([str(ffmpeg), "-v", "error", "-i", str(media_path), "-f", "null", "-"])


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: smoke-test.py /path/to/yt-dlp /path/to/ffmpeg /path/to/app-integration-runner", file=sys.stderr)
        return 2

    yt_dlp = pathlib.Path(sys.argv[1]).resolve()
    ffmpeg = pathlib.Path(sys.argv[2]).resolve()
    app_runner = pathlib.Path(sys.argv[3]).resolve()
    if not yt_dlp.is_file() or not ffmpeg.is_file() or not app_runner.is_file():
        print("required executable is missing", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="media-downloader-smoke-") as temporary:
        root = pathlib.Path(temporary)
        source_dir = root / "source"
        video_dir = root / "video-output"
        mp3_dir = root / "mp3-output"
        app_video_dir = root / "app-video-output"
        app_mp3_dir = root / "app-mp3-output"
        app_converted_dir = root / "app-converted-output"
        playlist_success_dir = root / "playlist-success-output"
        playlist_partial_dir = root / "playlist-partial-output"
        playlist_mp3_dir = root / "playlist-mp3-output"
        playlist_cancel_dir = root / "playlist-cancel-output"
        playlist_conversion_failure_dir = root / "playlist-conversion-failure-output"
        fake_tools_dir = root / "fake-tools"
        source_dir.mkdir()
        video_dir.mkdir()
        mp3_dir.mkdir()
        app_video_dir.mkdir()
        app_mp3_dir.mkdir()
        app_converted_dir.mkdir()
        playlist_success_dir.mkdir()
        playlist_partial_dir.mkdir()
        playlist_mp3_dir.mkdir()
        playlist_cancel_dir.mkdir()
        playlist_conversion_failure_dir.mkdir()
        fake_tools_dir.mkdir()
        source_video = source_dir / "sample.mp4"
        source_4k_video = source_dir / "sample-4k.mp4"

        run(
            [
                str(ffmpeg),
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=c=0x3478F6:s=640x360:d=1",
                "-f",
                "lavfi",
                "-i",
                "sine=frequency=880:duration=1",
                "-shortest",
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                str(source_video),
            ]
        )
        run(
            [
                str(ffmpeg),
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=c=0x34C759:s=3840x2160:r=1:d=1",
                "-f",
                "lavfi",
                "-i",
                "sine=frequency=440:duration=1",
                "-shortest",
                "-c:v",
                "libx264",
                "-preset",
                "ultrafast",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                str(source_4k_video),
            ]
        )

        fake_playlist_tool = pathlib.Path(__file__).resolve().parent / "fixtures" / "fake-playlist-yt-dlp.sh"
        fake_yt_dlp = fake_tools_dir / "yt-dlp"
        shutil.copy2(fake_playlist_tool, fake_yt_dlp)
        fake_yt_dlp.chmod(0o755)

        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(source_dir))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        source_url = f"http://127.0.0.1:{server.server_port}/sample.mp4"

        try:
            common = [
                str(yt_dlp),
                "--ignore-config",
                "--newline",
                "--no-update",
                "--no-playlist",
                "--ffmpeg-location",
                str(ffmpeg),
                "--print",
                "before_dl:__MD_TITLE__%(title)s",
                "--print",
                "after_move:__MD_FILE__%(filepath)s",
            ]
            video_result = run(
                common
                + [
                    "-f",
                    "bv*+ba/b",
                    "--merge-output-format",
                    "mp4",
                    "--embed-metadata",
                    "-P",
                    str(video_dir),
                    source_url,
                ]
            )
            mp3_result = run(
                common
                + [
                    "-x",
                    "--audio-format",
                    "mp3",
                    "--audio-quality",
                    "0",
                    "--embed-metadata",
                    "-P",
                    str(mp3_dir),
                    source_url,
                ]
            )
            app_environment = os.environ.copy()
            app_environment["PATH"] = f"{yt_dlp.parent}:{ffmpeg.parent}:{app_environment.get('PATH', '')}"
            app_video_result = run(
                [str(app_runner), source_url, str(app_video_dir), "video"],
                environment=app_environment,
            )
            app_mp3_result = run(
                [str(app_runner), source_url, str(app_mp3_dir), "mp3"],
                environment=app_environment,
            )
            app_converted_result = run(
                [str(app_runner), source_url, str(app_converted_dir), "video", "ultraHD2160"],
                environment=app_environment,
            )

            playlist_environment = app_environment.copy()
            playlist_environment["PATH"] = f"{fake_tools_dir}:{ffmpeg.parent}:{playlist_environment.get('PATH', '')}"
            playlist_environment["MD_FAKE_MEDIA_SOURCE"] = str(source_4k_video)
            playlist_inspection_result = run(
                [str(app_runner), "--inspect-playlist", "https://example.invalid/playlist"],
                environment=playlist_environment,
            )
            confirmation_state_result = run(
                [str(app_runner), "--check-confirmations"],
                environment=playlist_environment,
            )
            playlist_success_result = run(
                [
                    str(app_runner),
                    "https://example.invalid/playlist",
                    str(playlist_success_dir),
                    "video",
                    "ultraHD2160",
                    "120",
                    "true",
                ],
                environment=playlist_environment,
            )
            partial_environment = playlist_environment.copy()
            partial_environment["MD_FAKE_PLAYLIST_FAILURE"] = "1"
            playlist_partial_result = run(
                [
                    str(app_runner),
                    "https://example.invalid/playlist",
                    str(playlist_partial_dir),
                    "video",
                    "ultraHD2160",
                    "120",
                    "true",
                ],
                environment=partial_environment,
            )
            conversion_failure_environment = playlist_environment.copy()
            conversion_failure_environment["MD_FAKE_CONVERSION_FAILURE"] = "1"
            playlist_conversion_failure_result = run(
                [
                    str(app_runner),
                    "https://example.invalid/playlist",
                    str(playlist_conversion_failure_dir),
                    "video",
                    "ultraHD2160",
                    "120",
                    "true",
                ],
                environment=conversion_failure_environment,
            )
            playlist_mp3_result = run(
                [
                    str(app_runner),
                    "https://example.invalid/playlist",
                    str(playlist_mp3_dir),
                    "mp3",
                    "best",
                    "120",
                    "true",
                ],
                environment=playlist_environment,
            )
            cancel_environment = playlist_environment.copy()
            cancel_environment["MD_FAKE_PLAYLIST_DELAY"] = "5"
            playlist_cancel_result = run(
                [
                    str(app_runner),
                    "https://example.invalid/playlist",
                    str(playlist_cancel_dir),
                    "video",
                    "ultraHD2160",
                    "1",
                    "true",
                ],
                environment=cancel_environment,
                check=False,
            )
        finally:
            server.shutdown()
            server.server_close()

        video_files = list(video_dir.glob("*.mp4"))
        mp3_files = list(mp3_dir.glob("*.mp3"))
        if len(video_files) != 1 or len(mp3_files) != 1:
            print(video_result.stdout, file=sys.stderr)
            print(mp3_result.stdout, file=sys.stderr)
            print("expected one MP4 and one MP3 output", file=sys.stderr)
            return 1

        for result in (video_result, mp3_result):
            if "__MD_TITLE__" not in result.stdout or "__MD_FILE__" not in result.stdout:
                print(result.stdout, file=sys.stderr)
                print("expected title and output-file markers", file=sys.stderr)
                return 1

        verify_media(ffmpeg, video_files[0])
        verify_media(ffmpeg, mp3_files[0])
        app_video_files = list(app_video_dir.glob("*.mp4"))
        app_mp3_files = list(app_mp3_dir.glob("*.mp3"))
        app_converted_files = list(app_converted_dir.glob("*.mp4"))
        playlist_success_files = list(playlist_success_dir.glob("*.mp4"))
        playlist_partial_files = list(playlist_partial_dir.glob("*.mp4"))
        playlist_mp3_files = list(playlist_mp3_dir.glob("*.mp3"))
        playlist_conversion_failure_files = list(playlist_conversion_failure_dir.glob("*.mp4"))
        if len(app_video_files) != 1 or len(app_mp3_files) != 1 or len(app_converted_files) != 1:
            print(app_video_result.stdout, file=sys.stderr)
            print(app_mp3_result.stdout, file=sys.stderr)
            print(app_converted_result.stdout, file=sys.stderr)
            print("app integration runner did not produce expected files", file=sys.stderr)
            return 1
        if len(playlist_mp3_files) != 3 or "outputs=3 succeeded=3 failed=0" not in playlist_mp3_result.stdout:
            print(playlist_mp3_result.stdout, file=sys.stderr)
            print("MP3 playlist integration summary is incorrect", file=sys.stderr)
            return 1
        if playlist_cancel_result.returncode == 0 or "timed out" not in playlist_cancel_result.stdout:
            print(playlist_cancel_result.stdout, file=sys.stderr)
            print("playlist cancellation did not report a timeout", file=sys.stderr)
            return 1
        if list(playlist_cancel_dir.glob(".*.converting.mp4")):
            print("playlist cancellation left a conversion temporary file", file=sys.stderr)
            return 1
        if len(playlist_success_files) != 3 or len(playlist_partial_files) != 2:
            print(playlist_success_result.stdout, file=sys.stderr)
            print(playlist_partial_result.stdout, file=sys.stderr)
            print("playlist integration runner produced unexpected file counts", file=sys.stderr)
            return 1
        if "playlist=true count=3 title=Integration Playlist" not in playlist_inspection_result.stdout:
            print(playlist_inspection_result.stdout, file=sys.stderr)
            print("playlist inspection did not return the expected metadata", file=sys.stderr)
            return 1
        if "PASS: playlist confirmation" not in confirmation_state_result.stdout:
            print(confirmation_state_result.stdout, file=sys.stderr)
            print("playlist confirmation settings were not honored", file=sys.stderr)
            return 1
        if "outputs=3 succeeded=3 failed=0" not in playlist_success_result.stdout:
            print(playlist_success_result.stdout, file=sys.stderr)
            print("successful playlist summary is incorrect", file=sys.stderr)
            return 1
        if "outputs=2 succeeded=2 failed=1" not in playlist_partial_result.stdout:
            print(playlist_partial_result.stdout, file=sys.stderr)
            print("partial playlist summary is incorrect", file=sys.stderr)
            return 1
        if (
            len(playlist_conversion_failure_files) != 3
            or "outputs=3 succeeded=2 failed=1" not in playlist_conversion_failure_result.stdout
        ):
            print(playlist_conversion_failure_result.stdout, file=sys.stderr)
            print("conversion-failure playlist summary is incorrect", file=sys.stderr)
            return 1
        retained_failure_files = [path for path in playlist_conversion_failure_files if "Item 2" in path.name]
        if len(retained_failure_files) != 1 or not retained_failure_files[0].read_text().startswith("invalid media"):
            print("failed conversion did not retain its original source file", file=sys.stderr)
            return 1
        verify_media(ffmpeg, app_video_files[0])
        verify_media(ffmpeg, app_mp3_files[0])
        verify_media(ffmpeg, app_converted_files[0])
        converted_probe = run(
            [str(ffmpeg), "-hide_banner", "-i", str(app_converted_files[0])],
            check=False,
        ).stdout
        if "Video: hevc" not in converted_probe or "(hvc1" not in converted_probe or "Audio: aac" not in converted_probe:
            print(converted_probe, file=sys.stderr)
            print("converted output is not QuickTime-compatible HEVC/AAC", file=sys.stderr)
            return 1
        for playlist_file in playlist_success_files + playlist_partial_files:
            verify_media(ffmpeg, playlist_file)
            playlist_probe = run(
                [str(ffmpeg), "-hide_banner", "-i", str(playlist_file)],
                check=False,
            ).stdout
            if "Video: hevc" not in playlist_probe or "(hvc1" not in playlist_probe or "Audio: aac" not in playlist_probe:
                print(playlist_probe, file=sys.stderr)
                print("playlist output is not QuickTime-compatible HEVC/AAC", file=sys.stderr)
                return 1
        for playlist_file in playlist_conversion_failure_files:
            if "Item 2" in playlist_file.name:
                continue
            verify_media(ffmpeg, playlist_file)
        for playlist_mp3_file in playlist_mp3_files:
            verify_media(ffmpeg, playlist_mp3_file)
        print(app_video_result.stdout.strip())
        print(app_mp3_result.stdout.strip())
        print(app_converted_result.stdout.strip())
        print(playlist_success_result.stdout.strip())
        print(playlist_inspection_result.stdout.strip())
        print(confirmation_state_result.stdout.strip())
        print(playlist_partial_result.stdout.strip())
        print(playlist_conversion_failure_result.stdout.strip())
        print(playlist_mp3_result.stdout.strip())
        print("PASS: playlist cancellation cleaned temporary state")
        print(f"PASS: video={video_files[0].name}, mp3={mp3_files[0].name}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
