# ytj Technical Architecture

## 1. What is `ytj`?
`ytj` is a zero-config, highly opinionated, cross-platform wrapper for the popular media downloader `yt-dlp`. It provides a clean, beautiful Command Line Interface (CLI) experience while abstracting away the complex arguments and configuration flags normally required by `yt-dlp`.

## 2. What it Does
- **Sensible Defaults:** Automatically downloads the highest quality Video + Audio (MP4) and organizes them into an intuitive folder structure (`downloads/<Uploader>/<Title>.<Ext>`).
- **Dependency Management:** Acts as a self-bootstrapping tool. If `yt-dlp` is not found on the host system, `ytj` detects the Operating System (Windows, macOS, or Linux) and automatically downloads the correct binary release directly from GitHub.
- **UI Enhancement:** Intercepts execution to draw a clean, padded "Execution Panel" dashboard detailing the target and active options, before handing control over to `yt-dlp`'s native dynamic progress bar.
- **Quality of Life Translations:** Translates simple shorthand flags (e.g., `--subs`, `--thumb`, `--no-sponsors`) into their complex, multi-argument `yt-dlp` equivalents.

## 3. Codebase Structure
The project is structured to maximize cross-platform compatibility while keeping the core logic centralized in a single file.

- `ytj.bat`: The Windows Command Prompt entry point. It transparently invokes the core PowerShell script while safely bypassing execution policy restrictions.
- `ytj` (Unix Shell Script): The macOS/Linux entry point. It detects the `pwsh` (PowerShell Core) environment and executes the core script.
- `ytj.ps1`: The core engine of the application. It handles all argument parsing, UI rendering, dependency resolution, and process execution.

## 4. Design Patterns

### The Facade Pattern
`ytj` fundamentally acts as a Facade. `yt-dlp` is an incredibly powerful tool with hundreds of configuration flags, which can be overwhelming for standard usage. `ytj` provides a simplified interface (`ytj <url> --audio`), shielding the user from the underlying complexity (`yt-dlp -x --audio-format mp3 -o ...`).

### Command Builder Pattern
Instead of executing commands conditionally, `ytj.ps1` iteratively builds an argument array (`$ytDlpArgs`). As the script parses user flags (like `$AudioOnly` or `$Subs`), it appends the corresponding `yt-dlp` parameters to the array. This keeps the final execution step pure and cleanly decoupled from the configuration step.

### Native Stream Passthrough
A critical design choice in `ytj` is the use of the native PowerShell Call Operator (`& $exePath $ytDlpArgs`) rather than background execution cmdlets like `Start-Process`. By executing the binary natively within the script's runspace, `yt-dlp` retains direct access to the standard output streams (`stdout`/`stderr`). This prevents output swallowing and allows `yt-dlp`'s dynamic progress bar (which relies on carriage returns `\r` to continually overwrite the console line) to function flawlessly.

### Defensive Parameter Binding
PowerShell's advanced parameter binder can occasionally hijack shorthand flags that happen to map to built-in system parameters (for example, `-v` being silently swallowed as `-Verbose`). `ytj` employs explicit `[switch]` definitions in its `param()` block to defensively capture these flags, ensuring they are safely routed to the custom execution logic rather than being consumed by the PowerShell runtime.
