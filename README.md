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

1. **Clone or Download** this repository.
2. Open your terminal in the downloaded folder.
3. On your first run, `ytj` will automatically detect your OS (Windows, Linux, or macOS) and seamlessly bootstrap the correct `yt-dlp` binary behind the scenes!

That's it. No `pip install`, no `brew install`, no manual paths.

*(Optional: Add the folder to your system `PATH` so you can use `ytj` anywhere!)*

### Updating

Since YouTube frequently changes its systems, you will occasionally need to update the underlying `yt-dlp` binary. You can easily do this by running:
```bash
ytj -U
```

## Usage

### Core Commands

**Download highest quality video (MP4)**
```bash
# Windows
ytj "https://youtube.com/watch?v=..."

# Mac / Linux
./ytj "https://youtube.com/watch?v=..."
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
| `--debug` | Enables extreme `yt-dlp` debugging logs (network traces, config hashes) |
| `--no-sponsors` | Integrates SponsorBlock to automatically skip ad/sponsor segments |
| `--subs` | Automatically embeds English subtitles if available |
| `--thumb` | Automatically embeds the high-resolution YouTube thumbnail |
| `-d` or `--dir` | Interactively select or specify a target download directory `ytj <url> -d [FolderName]` |
| `--playlist` | Force-allow downloading a playlist. **Note:** Passing a `@channel`, `/user/`, or `list=` URL will automatically trigger playlist mode! |
| `--sync` | Syncs a channel. Records finished videos to a master `ytj_archive.txt` file, allowing you to flawlessly resume interrupted downloads or fetch new uploads later. |

### Passthrough

`ytj` is a lightweight wrapper. Any argument it doesn't explicitly recognize will be passed directly to `yt-dlp`. This means you can still use all your favorite advanced `yt-dlp` flags!

**Example:**
```bash
ytj <link> --audio --cookies-from-browser chrome
```
