# -----------------------------------------------------------------------------
# DEFENSIVE PARAMETER BINDING
# We explicitly map [switch]$v and [switch]$d to prevent PowerShell's 
# generic binder from silently consuming "-v" as the built-in "-Verbose".
# -----------------------------------------------------------------------------
param(
    [switch]$v,
    [switch]$VerboseLog,
    [switch]$d,
    [switch]$DebugLog,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

$Url = $null
$AudioChapters = $false
$Chapters = $false
$AudioOnly = $false
$NoSponsors = $false
$Subs = $false
$Thumb = $false
$Playlist = $false
$Sync = $false
$UiMode = $false
$VerboseMode = $v.IsPresent -or $VerboseLog.IsPresent
$DebugMode = $d.IsPresent -or $DebugLog.IsPresent
if ($DebugMode) { $VerboseMode = $true }
$OtherArgs = @()
if ($DebugMode) { $OtherArgs += "-v" }

function Write-Panel {
    param([string]$Title, [string[]]$Lines, [ConsoleColor]$Color = 'Cyan')
    Write-Host ""
    Write-Host " $Title " -ForegroundColor $Color
    Write-Host "------------------------------------------------------------" -ForegroundColor $Color
    foreach ($line in $Lines) {
        Write-Host "  $line" -ForegroundColor White
    }
    Write-Host "------------------------------------------------------------" -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    param([string]$Type, [string]$Message)
    if ($Type -eq 'info') { Write-Host " -> $Message" -ForegroundColor Cyan }
    elseif ($Type -eq 'wait') { Write-Host " .. $Message" -ForegroundColor Yellow }
    elseif ($Type -eq 'success') { Write-Host " OK $Message" -ForegroundColor Green }
    elseif ($Type -eq 'error') { Write-Host " !! $Message" -ForegroundColor Red }
    else { Write-Host "    $Message" }
}

foreach ($arg in $ArgsList) {
    if ($arg -eq "--audio-chapters") { $AudioChapters = $true }
    elseif ($arg -eq "--chapters") { $Chapters = $true }
    elseif ($arg -in @("-a", "--audio")) { $AudioOnly = $true }
    elseif ($arg -eq "--verbose") { $VerboseMode = $true }
    elseif ($arg -eq "--debug") { $DebugMode = $true; $VerboseMode = $true; $OtherArgs += "-v" }
    elseif ($arg -eq "--no-sponsors") { $NoSponsors = $true }
    elseif ($arg -eq "--subs") { $Subs = $true }
    elseif ($arg -eq "--thumb") { $Thumb = $true }
    elseif ($arg -eq "--playlist") { $Playlist = $true }
    elseif ($arg -eq "--sync") { $Sync = $true }
    elseif ($arg -eq "--ui") { $UiMode = $true }
    elseif ($arg -match "^https?://") { $Url = $arg }
    elseif (-not $Url -and $arg -notmatch "^-") { $Url = $arg }
    else { $OtherArgs += $arg }
}

if (-not $Url) {
    $helpLines = @(
        "USAGE: ytj <link> [options]",
        "",
        "CORE COMMANDS",
        "  <link>             [MP4] Download highest quality",
        "  --audio-chapters   [MP3] Download audio only and split by chapters",
        "  --chapters         [MP4] Download video and split by chapters",
        "",
        "QUALITY OF LIFE EXTRAS",
        "  -a, --audio        [MP3] Download audio only",
        "  -v, --verbose      [LOG] Show standard yt-dlp output (disable quiet mode)",
        "  -d, --debug        [LOG] Show extreme yt-dlp debug output",
        "  --no-sponsors      [ON]  Skip sponsor segments automatically",
        "  --subs             [CC]  Embed English subtitles",
        "  --thumb            [IMG] Embed high-res thumbnail",
        "  --playlist         [PL]  Allow downloading entire playlist",
        "  --sync             [SYNC] Sync a channel (skips previously downloaded)"
    )
    Write-Panel -Title "ytj : The Zero-Config yt-dlp Wrapper" -Lines $helpLines -Color Cyan
    exit 1
}

$ytDlpArgs = @()

# Safeguard: NEVER overwrite or modify any existing files
$ytDlpArgs += @("--no-overwrites", "--no-post-overwrites")

# Handle directory and naming based on Uploader
# yt-dlp will automatically create the uploader directory if it doesn't exist
$ytDlpArgs += @("-o", "downloads/%(uploader)s/%(title)s.%(ext)s")

if ($Sync) {
    # Syncing implies downloading a playlist/channel
    $Playlist = $true
    $ytDlpArgs += @("--download-archive", "ytj_archive.txt")
}

if (-not $Playlist) {
    $ytDlpArgs += "--no-playlist"
}
else {
    $ytDlpArgs += "--yes-playlist"
}

if ($AudioChapters) {
    $ytDlpArgs += @("-x", "--audio-format", "mp3", "--split-chapters")
}
elseif ($Chapters) {
    $ytDlpArgs += @("-f", "bv*+ba/b", "--merge-output-format", "mp4", "--split-chapters")
}
elseif ($AudioOnly) {
    $ytDlpArgs += @("-x", "--audio-format", "mp3")
}
else {
    $ytDlpArgs += @("-f", "bv*+ba/b", "--merge-output-format", "mp4")
}

if ($NoSponsors) {
    $ytDlpArgs += @("--sponsorblock-remove", "all")
}

if ($Subs) {
    $ytDlpArgs += @("--write-auto-sub", "--embed-subs")
}

if ($Thumb) {
    $ytDlpArgs += @("--write-thumbnail", "--embed-thumbnail")
}

if (-not $VerboseMode) {
    # Silence yt-dlp warnings but keep native informational logs (like 'already downloaded')
    $ytDlpArgs += @("--no-warnings")
}
$ytDlpArgs += @("--progress", "--console-title")

$ytDlpArgs += $OtherArgs
$ytDlpArgs += $Url


$modeStr = "Video + Audio (MP4)"
if ($AudioOnly -or $AudioChapters) { $modeStr = "Audio Only (MP3)" }
if ($Chapters) { $modeStr += " [Chapter Split]" }

$extrasStr = @()
if ($NoSponsors) { $extrasStr += "SponsorBlock" }
if ($Subs) { $extrasStr += "Subtitles" }
if ($Thumb) { $extrasStr += "Thumbnail" }
if ($Playlist) { $extrasStr += "Playlist/Sync" }

$execLines = @(
    "Target:  $Url",
    "Mode:    $modeStr"
)

if ($DebugMode) { $execLines += "Logging: Debug" }
elseif ($VerboseMode) { $execLines += "Logging: Verbose" }

$optionsText = if ($extrasStr.Count -gt 0) { $extrasStr -join ", " } else { "None" }
$execLines += "Options: $optionsText"
$execLines += "Status:  Initializing..."

Write-Panel -Title "Executing yt-dlp" -Lines $execLines -Color Magenta

# -----------------------------------------------------------------------------
# NATIVE BINARY RESOLUTION & AUTO-BOOTSTRAP
# -----------------------------------------------------------------------------
$os = "windows"
$binaryName = "yt-dlp.exe"

if (Get-Variable "IsMacOS" -ErrorAction SilentlyContinue -ValueOnly) {
    $os = "macos"
    $binaryName = "yt-dlp_macos"
} elseif (Get-Variable "IsLinux" -ErrorAction SilentlyContinue -ValueOnly) {
    $os = "linux"
    $binaryName = "yt-dlp"
}

$exePath = Join-Path -Path $PSScriptRoot -ChildPath $binaryName

if (-not (Test-Path $exePath)) {
    $globalCmd = Get-Command "yt-dlp" -ErrorAction SilentlyContinue
    if (-not $globalCmd) {
        Write-Step -Type "info" -Message "yt-dlp not found."
        Write-Step -Type "wait" -Message "Downloading the latest version for $os..."
        $downloadUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/$binaryName"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing
            if ($os -ne "windows") {
                & chmod +x $exePath
            }
            Write-Step -Type "success" -Message "yt-dlp downloaded successfully!"
        } catch {
            Write-Step -Type "error" -Message "Failed to download yt-dlp. Please install it manually from https://github.com/yt-dlp/yt-dlp/releases"
            exit 1
        }
    } else {
        $exePath = "yt-dlp"
    }
}

if ($UiMode) {
    if ($Url -eq "x") {
        Write-Host ""
        Write-Step -Type "info" -Message "Mock Single File UI Started"
        Write-Host ""
        for ($i = 0; $i -le 100; $i += 5) {
            $barLength = 25
            $filled = [math]::Floor(($i / 100) * $barLength)
            $empty = $barLength - $filled
            
            $bar = ""
            if ($filled -gt 0) {
                $bar += "=" * ($filled - 1)
                if ($i -lt 100) { $bar += ">" } else { $bar += "=" }
            }
            $bar += " " * $empty
            
            $speed = "3.2MiB/s"
            $eta = "00:0" + (10 - [math]::Floor($i/10))
            if ($eta -eq "00:010") { $eta = "00:10" }
            $text = "`r   Downloading [$bar] $i% | 52.7MiB | $speed | ETA: $eta   "
            Write-Host -NoNewline $text
            Start-Sleep -Milliseconds 100
        }
        Write-Host "`n"
        Write-Step -Type "success" -Message "Task finished (download complete)."
        exit 0
    }
    elseif ($Url -eq "p") {
        Write-Host ""
        Write-Step -Type "info" -Message "Playlist Sync Started (3 items)"
        Write-Host "------------------------------------------------------------"
        $items = @("DIGITAL DOPAMINE (jungle dnb)", "lostmemory.mp3", "intelligent liquid dnb mix")
        $states = @(0, 0, 0)
        $progress = @(0, 0, 0)

        # Pre-draw
        for ($i = 0; $i -lt 3; $i++) {
            Write-Host " [ ] $($i+1). $($items[$i])"
        }
        Write-Host "------------------------------------------------------------"
        
        $lineCount = 4 # 3 items + 1 dashed line

        for ($current = 0; $current -lt 3; $current++) {
            $states[$current] = 1 # downloading
            for ($p = 0; $p -le 100; $p += 15) {
                $progress[$current] = $p
                Write-Host "`e[${lineCount}A" -NoNewline
                for ($i = 0; $i -lt 3; $i++) {
                    if ($states[$i] -eq 0) {
                        Write-Host " [ ] $($i+1). $($items[$i])                                "
                    } elseif ($states[$i] -eq 1) {
                        $bar = "$($progress[$i])% (3.2MiB/s)"
                        Write-Host " [~] $($i+1). $($items[$i]) - $bar                      " -ForegroundColor Cyan
                    } else {
                        Write-Host " [x] $($i+1). $($items[$i])                                " -ForegroundColor Green
                    }
                }
                Write-Host "------------------------------------------------------------"
                Start-Sleep -Milliseconds 150
            }
            $states[$current] = 2 # done
        }
        
        # Final Draw
        Write-Host "`e[${lineCount}A" -NoNewline
        for ($i = 0; $i -lt 3; $i++) {
            Write-Host " [x] $($i+1). $($items[$i])                                " -ForegroundColor Green
        }
        Write-Host "------------------------------------------------------------"
        Write-Host ""
        Write-Step -Type "success" -Message "Playlist Sync Complete."
        exit 0
    }
}

# -----------------------------------------------------------------------------
# NATIVE STREAM PASSTHROUGH OR UI PIPELINE
# -----------------------------------------------------------------------------
if ($UiMode -and $Url -ne "x" -and $Url -ne "p") {
    $ytDlpArgs += @("--newline", "--progress-template", "download:YTJ_PROG:%(progress.percent)s_YTJ_%(progress._speed_str)s_YTJ_%(progress._eta_str)s_YTJ_%(progress._total_bytes_estimate_str)s")
    
    if ($Playlist) {
        Write-Host ""
        Write-Step -Type "info" -Message "Playlist Sync Started"
        Write-Host "------------------------------------------------------------"
    } else {
        Write-Host ""
    }

    $currentTitle = "Unknown"
    $completedItems = @()
    $firstPrint = $true

    & $exePath $ytDlpArgs 2>&1 | ForEach-Object {
        $line = $_.ToString()
        
        if ($line -match "YTJ_PROG:\s*([\d\.NA]+)\s*_YTJ_(.*)_YTJ_(.*)_YTJ_(.*)") {
            $pStr = $matches[1]
            if ($pStr -eq "NA") { $p = 100 } else { $p = [math]::Round([float]$pStr) }
            $speed = $matches[2]
            $eta = $matches[3]
            $total = $matches[4]
            
            if (-not $Playlist) {
                $barLength = 25
                $filled = [math]::Floor(($p / 100) * $barLength)
                $empty = $barLength - $filled
                $bar = ""
                if ($filled -gt 0) {
                    $bar += "=" * ($filled - 1)
                    if ($p -lt 100) { $bar += ">" } else { $bar += "=" }
                }
                $bar += " " * $empty
                Write-Host "`r   Downloading [$bar] $p% | $total | $speed | ETA: $eta   " -NoNewline
            } else {
                if (-not $firstPrint) { Write-Host "`e[1A" -NoNewline }
                $firstPrint = $false
                Write-Host " [~] $($completedItems.Count + 1). $currentTitle - $p% ($speed)                      " -ForegroundColor Cyan
            }
        }
        elseif ($line -match "\[download\] Destination: (.*)") {
            $currentTitle = Split-Path $matches[1] -Leaf
            if ($Playlist) {
                $firstPrint = $true
            }
        }
        elseif ($line -match "\[download\] (.*) has already been downloaded") {
            $currentTitle = Split-Path $matches[1] -Leaf
            if ($Playlist) {
                Write-Host " [x] $($completedItems.Count + 1). $currentTitle (Already downloaded)                      " -ForegroundColor Green
                $completedItems += $currentTitle
                $firstPrint = $true
            } else {
                Write-Host "`r   [x] $currentTitle (Already downloaded)                                " -ForegroundColor Green
            }
        }
        elseif ($line -match "\[download\] 100% of") {
            if ($Playlist) {
                if (-not $firstPrint) { Write-Host "`e[1A" -NoNewline }
                Write-Host " [x] $($completedItems.Count + 1). $currentTitle                                      " -ForegroundColor Green
                $completedItems += $currentTitle
                $firstPrint = $true
            } else {
                Write-Host "`n"
            }
        }
        elseif ($VerboseMode -and -not ($line -match "^YTJ_PROG")) {
            # Only print raw logs if verbose is enabled, but note that it breaks ASCII alignment
            Write-Host $line
        }
    }
    
    if ($Playlist) {
        Write-Host "------------------------------------------------------------"
        Write-Host ""
        Write-Step -Type "success" -Message "Playlist Sync Complete."
    } else {
        Write-Step -Type "success" -Message "Task finished."
    }
    exit $LASTEXITCODE
}
else {
    # We use the native call operator (&) instead of Start-Process.
    # This prevents output buffer swallowing and guarantees yt-dlp's 
    # \r dynamic progress bar renders correctly in real-time.
    & $exePath $ytDlpArgs
    exit $LASTEXITCODE
}
