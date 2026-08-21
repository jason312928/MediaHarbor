# MediaHarbor Agent Interface

MediaHarbor exposes a non-interactive command-line interface for Codex, Claude Code, shell scripts, and other local agents. It uses the same `YTDLPService` as the App, including browser cookies, FFmpeg discovery, temporary-file cleanup, subtitle conversion, and DOCX export.

## Invocation

From a source checkout:

```bash
swift run MediaHarbor capabilities
swift run MediaHarbor download "https://example.com/video" --quality 1080p
```

From an installed App:

```bash
/Applications/MediaHarbor.app/Contents/MacOS/MediaHarbor capabilities
/Applications/MediaHarbor.app/Contents/MacOS/MediaHarbor download "https://example.com/video" --quality best
```

Invoke the executable directly. Do not use `open -a MediaHarbor --args ...`, because an agent needs the process exit code and JSONL standard output.

## Discovery and commands

Always begin integration by running:

```bash
MediaHarbor capabilities
```

It reports the interface schema version, supported command values, yt-dlp version, and detected FFmpeg path.

```text
MediaHarbor analyze URL [options]
MediaHarbor download URL [options]
MediaHarbor install-engine
MediaHarbor --help
```

Examples:

```bash
# Best video, deterministic defaults, explicit output directory
MediaHarbor download URL --quality best --output "$PWD/downloads" --no-app-settings

# Audio only
MediaHarbor download URL --quality audio --output "$PWD/downloads"

# Video plus Chinese/English subtitles
MediaHarbor download URL --quality 1080p --subtitles \
  --sub-langs "zh-Hans,zh-Hant,en" --sub-format srt

# Subtitle transcript as a real Microsoft Word document
MediaHarbor download URL --quality subtitles \
  --sub-langs "zh-Hans,en" --sub-format docx

# Signed-in browser session for authorized restricted media
MediaHarbor analyze URL --cookies chrome
```

By default, commands inherit the user's MediaHarbor App settings. Add `--no-app-settings` to start from deterministic defaults; explicit command-line options still take precedence.

## JSON Lines protocol

Operational commands write one JSON object per line to standard output. Human-readable diagnostics are written to standard error. Every object contains:

```json
{"schemaVersion":1,"event":"progress","data":{"fraction":0.425,"percent":42.5,"speed":"3.2MiB/s","eta":"00:12"}}
```

Event names are `status`, `capabilities`, `result`, `progress`, `complete`, and `error`. Agents should ignore unknown event names and unknown object fields for forward compatibility. The final `complete` event contains the saved path. `analyze` returns media metadata in its `result` event.

Exit codes:

| Code | Meaning |
| ---: | --- |
| 0 | Success |
| 2 | Invalid command or option |
| 3 | yt-dlp is missing; the agent may ask the user before running `install-engine` |
| 4 | Analysis or download failed |
| 130 | Cancelled with SIGINT or SIGTERM |

When an agent cancels the MediaHarbor process, MediaHarbor terminates its yt-dlp child and lets the task-scoped temporary directory cleanup complete.

## Agent guidance

- Run `capabilities`; do not assume a particular installed version.
- Quote URLs and filesystem paths.
- Use an explicit `--output` and `--no-app-settings` when reproducibility matters.
- Use browser cookies only for media the user is authorized to access. MediaHarbor passes the selected browser name to yt-dlp and does not store cookie contents.
- Do not parse localized human text. Parse JSONL and use the process exit code.
- Do not report success until the `complete` event and exit code 0 are both observed.
