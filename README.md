# ytj: The yt-dlp Wrapper

`ytj` is a zero-configuration, quality-of-life wrapper around `yt-dlp` designed to make downloading content from YouTube and other platforms as frictionless as possible. It takes the most common, complex `yt-dlp` flag combinations and simplifies them into intuitive commands, while automatically organizing your files and protecting your existing data.

## Features

- **Smart Organization:** Automatically downloads and organizes videos into directories named after the channel/uploader.
- **Data Protection:** Built-in safeguards (`--no-overwrites`, `--no-post-overwrites`) guarantee that `ytj` will *never* overwrite, edit, modify, or delete any of your existing files.
- **Sensible Defaults:** Grabs the absolute highest quality video and audio and merges them into an MP4 file. Playlists are disabled by default to prevent accidental mass-downloads.
- **Chapter Splitting:** Easily download entire videos or audio tracks and automatically slice them into individual files per chapter.
- **SponsorBlock Integration:** Automatically skip built-in sponsor segments with a single flag.

## Installation

`ytj` is truly zero-configuration and cross-platform. It automatically manages its own dependencies!

1. Place `ytj.ps1` (and `ytj.bat` if on Windows) into any directory.
2. Add that directory to your system's `PATH` environment variable so you can run `ytj` from anywhere in your command line.
3. On your first run, `ytj` will automatically detect your OS (Windows, Linux, or macOS) and download the correct `yt-dlp` binary if you don't already have it installed.

### Updating

Since YouTube frequently changes its systems, you will occasionally need to update the underlying `yt-dlp` binary. You can easily do this by running:
```bash
ytj -U
```

## Usage

### Core Commands

**Download highest quality video (MP4)**
```bash
ytj "https://youtube.com/watch?v=..."
```

> [!WARNING]
> If your URL contains an ampersand (`&`), such as `&t=10s` or `&pp=...`, you **must** wrap the entire URL in quotes. Otherwise, Windows Command Prompt and PowerShell will treat the `&` as a command separator and throw errors like `'t' is not recognized as an internal or external command`.

**Download and split video by chapters (MP4)**
```bash
ytj <link> --chapters
```

**Download audio only and split by chapters (MP3)**
```bash
ytj <link> --audio-chapters
```

### Quality-of-Life Flags

You can mix and match these flags with any command:

| Flag | Description |
| :--- | :--- |
| `-a` or `--audio` | Download the highest quality audio (MP3 only) |
| `-v` or `--verbose` | Disables quiet mode and shows standard `yt-dlp` output (no spam) |
| `-d` or `--debug` | Enables extreme `yt-dlp` debugging logs (network traces, config hashes) |
| `--no-sponsors` | Integrates SponsorBlock to automatically skip ad/sponsor segments |
| `--subs` | Automatically embeds English subtitles if available |
| `--thumb` | Automatically embeds the high-resolution YouTube thumbnail |
| `--playlist` | Required if you want to download an entire playlist (disabled by default) |
| `--sync` | Syncs a channel. Automatically enables playlist downloads and records finished videos to a master `ytj_archive.txt` file, allowing you to flawlessly resume interrupted downloads or fetch new uploads later. |

### Passthrough

`ytj` is a lightweight wrapper. Any argument it doesn't explicitly recognize will be passed directly to `yt-dlp`. This means you can still use all your favorite advanced `yt-dlp` flags!

**Example:**
```bash
ytj <link> --audio --cookies-from-browser chrome
```
