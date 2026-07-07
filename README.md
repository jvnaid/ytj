<div align="center">
  <h1>ytj 🚀</h1>
  <p><strong>A zero-configuration, quality-of-life wrapper around yt-dlp.</strong></p>
  
  [![npm version](https://img.shields.io/npm/v/@jvnaid/ytj.svg?style=flat-square)](https://www.npmjs.com/package/@jvnaid/ytj)
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)
</div>

---

`ytj` transforms complex `yt-dlp` commands into a frictionless, interactive terminal experience. It automatically organizes files, extracts live metadata inline without extra API calls, and protects your existing data—all wrapped in a beautiful UI.

## ✨ Features

* 📁 **Smart Organization:** Automatically routes downloads into directories named after the uploader/channel.
* ⌨️ **Interactive Folder Routing:** Use the `-d` flag to pull up an arrow-key menu and instantly redirect downloads into any existing sub-folder.
* 🛡️ **Data Protection:** Built-in safeguards (`--no-overwrites`) guarantee `ytj` will *never* overwrite or delete your existing files.
* 📺 **Native UI Streaming:** Hijacks `yt-dlp`'s raw output to present a clean, auto-updating inline progress bar and metadata readout.
* 🔄 **Auto-Playlists:** Passing a `@channel`, `/user/`, or `list=` URL automatically swaps to the tabular Playlist Sync interface.
* ✂️ **Chapter Splitting & SponsorBlock:** Instantly slice videos/audio by chapters or skip sponsor segments with single flags.

---

## 📦 Installation

`ytj` is completely zero-configuration and cross-platform. You don't even need `yt-dlp` installed—it automatically manages and bootstraps its own dependencies!

### Option A: Global NPM Install (Recommended)
If you have Node.js installed, simply grab it globally:
```bash
npm install -g @jvnaid/ytj
```

### Option B: Clone & Play
Don't want to use NPM? No problem.
1. **Clone** this repository.
2. Open your terminal in the downloaded folder.
3. Run `./ytj <url>`! On its first run, it will automatically detect your OS and download the correct `yt-dlp` binary behind the scenes.

*(Optional: Add the folder to your system `PATH` to use `ytj` anywhere!)*

---

## ⚡ Usage

### Core Commands

**Download highest quality video (MP4)**
```bash
ytj "https://youtube.com/watch?v=..."
```
> [!WARNING]
> If your URL contains an ampersand (`&`), such as `&t=10s`, you **must** wrap the entire URL in quotes. Otherwise, your terminal will treat the `&` as a command separator!

**Download and split video by chapters (MP4)**
```bash
ytj <link> --chapters
```

**Download audio only and split by chapters (MP3)**
```bash
ytj <link> --audio-chapters
```

---

### 🧰 Quality-of-Life Flags

Mix and match these flags with any command:

| Flag | Description |
| :--- | :--- |
| `-a`, `--audio` | Download the highest quality audio (MP3 only) |
| `-v`, `--verbose` | Disables quiet mode and shows standard `yt-dlp` output (no spam) |
| `--debug` | Enables extreme `yt-dlp` debugging logs (network traces, config hashes) |
| `--no-sponsors` | Integrates SponsorBlock to automatically skip ad/sponsor segments |
| `--subs` | Automatically embeds English subtitles if available |
| `--thumb` | Automatically embeds the high-resolution YouTube thumbnail |
| `-d`, `--dir` | Interactively select a target download folder via an **Arrow-Key Menu**, or specify one manually: `ytj <url> -d MyFolder` |
| `--playlist` | Force-allow downloading a playlist. *(Triggered automatically by channel URLs)* |
| `--sync` | Syncs a channel. Records finished videos to `ytj_archive.txt`, allowing you to flawlessly resume interrupted mass-downloads. |

### 🛠️ Passthrough

`ytj` is a lightweight wrapper. Any argument it doesn't explicitly recognize will be seamlessly passed directly to `yt-dlp`. You lose zero functionality!

```bash
ytj <link> --audio --cookies-from-browser chrome
```

---

### 🔄 Updating

Since streaming platforms frequently change their systems, you will occasionally need to update the underlying `yt-dlp` binary. `ytj` makes this a single command:
```bash
ytj -U
```
