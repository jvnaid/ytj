# -----------------------------------------------------------------------------
$ArgsList = $args

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
$ChooseDir = $false
$TargetDirName = $null
$VerboseMode = $false
$DebugMode = $false
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

function Show-Menu {
    param(
        [string]$Title,
        [string[]]$Options
    )
    if ([Console]::IsOutputRedirected) {
        Write-Host "Interactive menu cannot be displayed. Defaulting to: $($Options[0])"
        return $Options[0]
    }
    
    $selectedIndex = 0
    Write-Host "`n $Title" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan

    # Pre-allocate lines to prevent scrolling bugs during redraws
    for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "" }
    $cursorTop = [Console]::CursorTop - $Options.Count

    [Console]::CursorVisible = $false

    try {
        while ($true) {
            [Console]::SetCursorPosition(0, $cursorTop)
            for ($i = 0; $i -lt $Options.Count; $i++) {
                if ($i -eq $selectedIndex) {
                    Write-Host " > $($Options[$i]) ".PadRight(50) -ForegroundColor Black -BackgroundColor Cyan
                } else {
                    Write-Host "   $($Options[$i]) ".PadRight(50)
                }
            }
            
            $keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($keyInfo.VirtualKeyCode -eq 38) { # Up arrow
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            } elseif ($keyInfo.VirtualKeyCode -eq 40) { # Down arrow
                if ($selectedIndex -lt ($Options.Count - 1)) { $selectedIndex++ }
            } elseif ($keyInfo.VirtualKeyCode -eq 13) { # Enter
                break
            }
        }
    } finally {
        [Console]::CursorVisible = $true
        # Clear the menu lines
        [Console]::SetCursorPosition(0, $cursorTop)
        for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "".PadRight(50) }
        [Console]::SetCursorPosition(0, $cursorTop)
    }
    
    return $Options[$selectedIndex]
}

function Get-YtjHomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($env:HOME) { return $env:HOME }
    return [Environment]::GetFolderPath("UserProfile")
}

function Get-YtjConfigDir {
    $homeDir = Get-YtjHomeDir
    $dir = Join-Path -Path $homeDir -ChildPath ".ytj"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-YtjConfigPath {
    return (Join-Path -Path (Get-YtjConfigDir) -ChildPath "config.json")
}

function Get-YtjGlobalArchivePath {
    return (Join-Path -Path (Get-YtjConfigDir) -ChildPath "archive.txt")
}

function Get-YtjConfig {
    $configPath = Get-YtjConfigPath
    $config = @{
        downloadDir = $null
    }
    if (Test-Path $configPath) {
        try {
            $json = Get-Content -Path $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($json.downloadDir) {
                $config.downloadDir = $json.downloadDir
            }
        } catch {}
    }
    return $config
}

function Set-YtjConfig {
    param([string]$DownloadDir)
    $configPath = Get-YtjConfigPath
    $config = @{
        downloadDir = $DownloadDir
    }
    $json = $config | ConvertTo-Json -Depth 2
    Set-Content -Path $configPath -Value $json -Force
}

function Show-YtjConfig {
    $config = Get-YtjConfig
    $configPath = Get-YtjConfigPath
    $globalArchive = Get-YtjGlobalArchivePath
    
    $defaultDir = (Join-Path -Path $PWD -ChildPath "downloads")
    $overrideDir = if ($config.downloadDir) { $config.downloadDir } else { "None (Using Default)" }
    $activeDir = if ($config.downloadDir -and (Test-Path $config.downloadDir)) { $config.downloadDir } else { $defaultDir }
    
    $lines = @(
        "Config File:       $configPath",
        "Global Archive:    $globalArchive",
        "",
        "Default Location:  $defaultDir",
        "Override Location: $overrideDir",
        "Active Location:   $activeDir"
    )
    Write-Panel -Title "ytj Configuration" -Lines $lines -Color Cyan
}

$DownloadConfigArg = $null
$SetDownloadConfig = $false
$ShowConfigOnly = $false

for ($idx = 0; $idx -lt $ArgsList.Count; $idx++) {
    $arg = $ArgsList[$idx]
    if ($arg -eq "--audio-chapters") { $AudioChapters = $true }
    elseif ($arg -eq "--chapters") { $Chapters = $true }
    elseif ($arg -in @("-a", "--audio")) { $AudioOnly = $true }
    elseif ($arg -in @("-v", "--verbose")) { $VerboseMode = $true }
    elseif ($arg -eq "--debug") { $DebugMode = $true; $VerboseMode = $true; $OtherArgs += "-v" }
    elseif ($arg -eq "--no-sponsors") { $NoSponsors = $true }
    elseif ($arg -eq "--subs") { $Subs = $true }
    elseif ($arg -eq "--thumb") { $Thumb = $true }
    elseif ($arg -eq "--playlist") { $Playlist = $true }
    elseif ($arg -in @("-d", "--dir")) { 
        $ChooseDir = $true 
        if (($idx + 1) -lt $ArgsList.Count -and $ArgsList[$idx+1] -notmatch "^-") {
            $TargetDirName = $ArgsList[$idx+1]
            $idx++
        }
    }
    elseif ($arg -eq "--download-config") {
        $SetDownloadConfig = $true
        if (($idx + 1) -lt $ArgsList.Count -and $ArgsList[$idx+1] -notmatch "^-") {
            $DownloadConfigArg = $ArgsList[$idx+1]
            $idx++
        }
    }
    elseif ($arg -in @("-c", "--config")) {
        $ShowConfigOnly = $true
    }
    elseif ($arg -eq "--sync") { $Sync = $true }
    elseif ($arg -eq "--ui") { $UiMode = $true }
    elseif ($arg -match "^https?://") { $Url = $arg }
    elseif (-not $Url -and $arg -notmatch "^-") { $Url = $arg }
    else { $OtherArgs += $arg }
}

if ($ShowConfigOnly) {
    Show-YtjConfig
    exit 0
}

if ($SetDownloadConfig) {
    if (-not $DownloadConfigArg -or $DownloadConfigArg -in @("default", "reset", "none")) {
        Set-YtjConfig -DownloadDir $null
        Write-Step -Type "success" -Message "Download directory reset to default (./downloads)."
    } else {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DownloadConfigArg)
        if (-not (Test-Path $resolved)) {
            try {
                New-Item -ItemType Directory -Path $resolved -Force | Out-Null
            } catch {
                Write-Step -Type "error" -Message "Could not create directory at '$resolved': $_"
                exit 1
            }
        }
        Set-YtjConfig -DownloadDir $resolved
        Write-Step -Type "success" -Message "Persistent download directory configured:"
        Write-Host "   $resolved`n" -ForegroundColor Cyan
    }
    exit 0
}

# Auto-detect playlists or profile IDs
if ($Url -match "list=" -or $Url -match "@" -or $Url -match "/channel/" -or $Url -match "/c/" -or $Url -match "/user/") {
    $Playlist = $true
}

if (-not $Url) {
    $helpLines = @(
        "USAGE: ytj <link> [options]",
        "",
        "CORE COMMANDS",
        "  <link>                   [MP4] Download highest quality",
        "  --audio-chapters         [MP3] Download audio only and split by chapters",
        "  --chapters               [MP4] Download video and split by chapters",
        "",
        "QUALITY OF LIFE EXTRAS",
        "  -a, --audio              [MP3] Download audio only",
        "  -v, --verbose            [LOG] Show standard yt-dlp output (disable quiet mode)",
        "  --debug                  [LOG] Show extreme yt-dlp debug output",
        "  --no-sponsors            [ON]  Skip sponsor segments automatically",
        "  --subs                   [CC]  Embed English subtitles",
        "  --thumb                  [IMG] Embed high-res thumbnail",
        "  -d, --dir [NAME]         [DIR] Select or create target download folder interactively",
        "  --playlist               [PL]  Allow downloading entire playlist",
        "  --sync                   [SYNC] Sync a channel (skips previously downloaded)",
        "",
        "CONFIGURATION",
        "  --download-config <DIR>  [CFG] Set persistent download directory (or 'default')",
        "  --config, -c             [CFG] Display active configuration and storage paths"
    )
    Write-Panel -Title "ytj : The Zero-Config yt-dlp Wrapper" -Lines $helpLines -Color Cyan
    exit 1
}

# Base Directory Resolution
$config = Get-YtjConfig
$defaultBaseDir = (Join-Path -Path $PWD -ChildPath "downloads")
$overrideBaseDir = $config.downloadDir
$activeBaseDir = $defaultBaseDir
$alternativeBaseDir = $null

if ($overrideBaseDir) {
    if (Test-Path $overrideBaseDir) {
        $activeBaseDir = $overrideBaseDir
        $alternativeBaseDir = $defaultBaseDir
    } else {
        Write-Step -Type "error" -Message "Configured directory is inaccessible: $overrideBaseDir"
        Write-Step -Type "wait" -Message "Falling back to default directory: $defaultBaseDir"
        $activeBaseDir = $defaultBaseDir
    }
} else {
    $alternativeBaseDir = $null
}

if (-not (Test-Path $activeBaseDir)) {
    New-Item -ItemType Directory -Path $activeBaseDir -Force | Out-Null
}

$ytDlpArgs = @()

# Safeguard: NEVER overwrite or modify any existing files
$ytDlpArgs += @("--no-overwrites", "--no-post-overwrites")

# Handle directory and naming based on Uploader
# yt-dlp will automatically create the uploader directory if it doesn't exist
$targetFolder = "%(uploader)s"
if ($ChooseDir) {
    if ($TargetDirName) {
        $targetFolder = $TargetDirName
        $newDir = Join-Path -Path $activeBaseDir -ChildPath $TargetDirName
        if (-not (Test-Path $newDir)) { New-Item -ItemType Directory -Path $newDir -Force | Out-Null }
    } else {
        $subdirs = Get-ChildItem -Path $activeBaseDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        
        $options = @()
        if ($subdirs) {
            $options += $subdirs
        }
        $options += "[Create New Folder...]"
        $options += "[Default: %(uploader)s]"
        
        $selection = Show-Menu -Title "Select Download Folder ($activeBaseDir):" -Options $options
        
        if ($selection -eq "[Create New Folder...]") {
            Write-Host "`n > Enter new folder name: " -ForegroundColor Yellow -NoNewline
            $newFolder = Read-Host
            if ([string]::IsNullOrWhiteSpace($newFolder)) {
                $targetFolder = "%(uploader)s"
            } else {
                $targetFolder = $newFolder.Trim()
                $newDir = Join-Path -Path $activeBaseDir -ChildPath $targetFolder
                if (-not (Test-Path $newDir)) { New-Item -ItemType Directory -Path $newDir -Force | Out-Null }
            }
        } elseif ($selection -ne "[Default: %(uploader)s]") {
            $targetFolder = $selection
        }
    }
}
$ytDlpArgs += @("-o", "$activeBaseDir/$targetFolder/%(title)s.%(ext)s")

# Global Archive Tracking
$globalArchive = Get-YtjGlobalArchivePath
$ytDlpArgs += @("--download-archive", $globalArchive)

# Cross-Path Duplicate Detection
$videoId = $null
if ($Url -match '(?:v=|youtu\.be\/|shorts\/|embed\/)([a-zA-Z0-9_-]{11})') {
    $videoId = $matches[1]
}

if ($videoId) {
    $foundInAlt = $null
    if ($alternativeBaseDir -and (Test-Path $alternativeBaseDir)) {
        $altMatch = Get-ChildItem -Path $alternativeBaseDir -Recurse -Filter "*$videoId*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($altMatch) {
            $foundInAlt = $altMatch.FullName
        }
    }
    
    $foundInActive = $null
    if (Test-Path $activeBaseDir) {
        $activeMatch = Get-ChildItem -Path $activeBaseDir -Recurse -Filter "*$videoId*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($activeMatch) {
            $foundInActive = $activeMatch.FullName
        }
    }

    if ($foundInAlt) {
        $noticeLines = @(
            "Video ID: [$videoId]",
            "Status:   Already exists in your alternative library!",
            "Location: $foundInAlt",
            "Target:   $activeBaseDir"
        )
        Write-Panel -Title "Notice: Cross-Path Duplicate Detected" -Lines $noticeLines -Color Yellow
    } elseif ($foundInActive) {
        Write-Step -Type "info" -Message "Video already present in active library: $foundInActive"
    }
}

if ($Sync) {
    # Syncing implies downloading a playlist/channel
    $Playlist = $true
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
    "Target:   $Url",
    "Mode:     $modeStr",
    "Save to:  $activeBaseDir/$targetFolder"
)

if ($DebugMode) { $execLines += "Logging:  Debug" }
elseif ($VerboseMode) { $execLines += "Logging:  Verbose" }

$optionsText = if ($extrasStr.Count -gt 0) { $extrasStr -join ", " } else { "None" }
$execLines += "Options:  $optionsText"
$execLines += "Archive:  $globalArchive"

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
        
        Write-Host " [Video] Never Gonna Give You Up - Rick Astley [3:32]" -ForegroundColor Cyan
        Write-Host " [Quality] Quality: 1080p60 (mp4) | Views: 1.4B" -ForegroundColor DarkGray
        
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
            $msg = "`r" + '   Downloading [' + $bar + '] ' + $i + '% | 52.7MiB | ' + $speed + ' | ETA: ' + $eta + '   '
            Write-Host -NoNewline $msg
            Start-Sleep -Milliseconds 100
        }
        Write-Host "`n"
        Write-Host " [Done] Saved to: downloads/Rick Astley/Never Gonna Give You Up.mp4" -ForegroundColor DarkGray
        Write-Host ""
        Write-Step -Type "success" -Message "Task finished (download complete)."
        exit 0
    }
    elseif ($Url -eq "p") {
        Write-Host ""
        Write-Step -Type "info" -Message "Playlist Sync Started (3 items)"
        Write-Host "------------------------------------------------------------"
        $items = @(
            "Never Gonna Give You Up [3:32] (Rick Astley)", 
            "Together Forever [3:24] (Rick Astley)", 
            "Whenever You Need Somebody [3:53] (Rick Astley)"
        )
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
    $metaFile = Join-Path -Path $PSScriptRoot -ChildPath ".ytj_meta.txt"
    if (Test-Path $metaFile) { Remove-Item $metaFile -Force -ErrorAction SilentlyContinue }
    
    $ytDlpArgs += @(
        "--print-to-file", "YTJ_META:%(duration_string)s_YTJ_%(resolution)s_YTJ_%(view_count)s_YTJ_%(ext)s", $metaFile,
        "--newline", 
        "--progress-template", "download:YTJ_PROG:%(progress.percent)s_YTJ_%(progress._speed_str)s_YTJ_%(progress._eta_str)s_YTJ_%(progress._total_bytes_estimate_str)s"
    )
    
    if ($Playlist) {
        Write-Host ""
        Write-Step -Type "info" -Message "Playlist Sync Started"
        Write-Host "------------------------------------------------------------"
    } else {
        Write-Host ""
    }

    $currentTitle = "Unknown"
    $currentUploader = "Unknown"
    $currentDuration = "?:??"
    $currentRes = "Unknown"
    $currentViews = "0"
    $currentExt = "mp4"
    $completedItems = @()
    $firstPrint = $true

    & $exePath $ytDlpArgs 2>&1 | ForEach-Object {
        $line = $_.ToString()
        
        if ($line -match "YTJ_PROG:\s*([\d\.NA]+)\s*_YTJ_(.*)_YTJ_(.*)_YTJ_(.*)") {
            $pStr = $matches[1].Trim()
            $speed = $matches[2].Trim()
            $eta = $matches[3].Trim()
            $total = $matches[4].Trim()
            
            $p = 0
            if ($pStr -match "[\d\.]+") { $p = [math]::Floor([double]$pStr) }
            
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
                $msg = "`r   Downloading [" + $bar + "] " + $p + "% | " + $total + " | " + $speed + " | ETA: " + $eta + "   "
                Write-Host -NoNewline $msg
            } else {
                if (-not $firstPrint) { Write-Host "`e[1A" -NoNewline }
                $firstPrint = $false
                Write-Host " [~] $($completedItems.Count + 1). $currentTitle [$currentDuration] - $p% ($speed)                      " -ForegroundColor Cyan
            }
        }
        elseif ($line -match "\[download\] Destination: (.*)") {
            $path = $matches[1]
            $currentTitle = Split-Path $path -Leaf
            $currentUploader = Split-Path (Split-Path $path -Parent) -Leaf
            
            # Attempt to read metadata from the file
            if (Test-Path $metaFile) {
                $lastMeta = Get-Content $metaFile | Select-Object -Last 1
                if ($lastMeta -match "YTJ_META:(.*)_YTJ_(.*)_YTJ_(.*)_YTJ_(.*)") {
                    $currentDuration = $matches[1]
                    $currentRes = $matches[2]
                    $currentViews = $matches[3]
                    $currentExt = $matches[4]
                }
            }

            if ($Playlist) {
                $firstPrint = $true
            } else {
                # Format view count nicely if it's a number
                $viewsStr = $currentViews
                if ($currentViews -match "^\d+$") {
                    $v = [long]$currentViews
                    if ($v -gt 1000000000) { $viewsStr = "$([math]::Round($v/1000000000, 1))B" }
                    elseif ($v -gt 1000000) { $viewsStr = "$([math]::Round($v/1000000, 1))M" }
                    elseif ($v -gt 1000) { $viewsStr = "$([math]::Round($v/1000, 1))K" }
                }
                
                Write-Host " [Video] $currentTitle ($currentUploader) [$currentDuration]" -ForegroundColor Cyan
                Write-Host " [Quality] Quality: $currentRes ($currentExt) | Views: $viewsStr" -ForegroundColor DarkGray
            }
        }
        elseif ($line -match "\[download\] (.*) has already been downloaded") {
            $path = $matches[1]
            $currentTitle = Split-Path $path -Leaf
            if ($Playlist) {
                Write-Host " [x] $($completedItems.Count + 1). $currentTitle (Already downloaded)                      " -ForegroundColor Green
                $completedItems += $currentTitle
                $firstPrint = $true
            } else {
                Write-Host " [Video] $currentTitle (Already downloaded)" -ForegroundColor Cyan
                Write-Host " [Done] Finished.                                " -ForegroundColor DarkGray
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
    
    if (Test-Path $metaFile) { Remove-Item $metaFile -Force -ErrorAction SilentlyContinue }
    
    if ($Playlist) {
        Write-Host "------------------------------------------------------------"
        Write-Host ""
        Write-Step -Type "success" -Message "Playlist Sync Complete."
    } else {
        Write-Host "`n [Done] Saved to: $path" -ForegroundColor DarkGray
        Write-Host ""
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
