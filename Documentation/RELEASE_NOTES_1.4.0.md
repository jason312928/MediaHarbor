# MediaHarbor 1.4.0

MediaHarbor 1.4.0 adds a JSONL command-line interface for coding agents and improves download reliability, subtitle export, and packaging.

## Highlights

- Add `capabilities`, `analyze`, `download`, and `install-engine` commands for Codex, Claude Code, and other agents.
- Export subtitle transcripts as native Microsoft Word DOCX documents.
- Restore live yt-dlp progress reporting and make cancellation reliably stop helper processes.
- Preserve recoverable download history and update yt-dlp atomically.
- Add browser sign-in recovery for sites that require cookies.
- Honor the browser selected in Settings when opening a sign-in page and reusing its cookies.
- Complete video downloads normally when DOCX subtitles are requested but the media has no subtitles.
- Redesign the Downloads screen with searchable status cards, sorting, richer progress, and a focused detail panel.
- Add best-available quality selection and improve thumbnail handling.
- Package the application with its MediaHarbor icon.

## Requirements

- macOS 14 Sonoma or later.
- The prebuilt package supports Apple Silicon (arm64).
- FFmpeg is recommended for merging and post-processing.
