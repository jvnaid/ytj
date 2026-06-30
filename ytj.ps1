param(
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
$OtherArgs = @()

foreach ($arg in $ArgsList) {
    if ($arg -eq "--audio-chapters") { $AudioChapters = $true }
    elseif ($arg -eq "--chapters") { $Chapters = $true }
    elseif ($arg -in @("-a", "--audio")) { $AudioOnly = $true }
    elseif ($arg -eq "--no-sponsors") { $NoSponsors = $true }
    elseif ($arg -eq "--subs") { $Subs = $true }
    elseif ($arg -eq "--thumb") { $Thumb = $true }
    elseif ($arg -eq "--playlist") { $Playlist = $true }
    elseif ($arg -eq "--sync") { $Sync = $true }
    elseif ($arg -match "^https?://") { $Url = $arg }
    elseif (-not $Url -and $arg -notmatch "^-") { $Url = $arg }
    else { $OtherArgs += $arg }
}

if (-not $Url) {
    Write-Host "Usage: ytj <link> [options]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Core commands:"
    Write-Host "  <link>             Download highest quality video + audio (mp4) into Uploader directory"
    Write-Host "  --audio-chapters   Download audio only (mp3) and split by chapters"
    Write-Host "  --chapters         Download video (mp4) and split by chapters"
    Write-Host ""
    Write-Host "Quality of life options:"
    Write-Host "  -a, --audio        Download audio only (mp3)"
    Write-Host "  --no-sponsors      Automatically remove sponsor segments"
    Write-Host "  --subs             Download and embed English subtitles"
    Write-Host "  --thumb            Download and embed high-res thumbnail"
    Write-Host "  --playlist         Allow downloading entire playlist (default: disabled)"
    Write-Host "  --sync             Seamlessly download a channel, recording finished videos"
    Write-Host "                     to ytj_archive.txt to skip them on future runs."
    Write-Host ""
    Write-Host "Any other yt-dlp arguments will be passed through directly."
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

$ytDlpArgs += $OtherArgs
$ytDlpArgs += $Url

$commandStr = "yt-dlp " + ($ytDlpArgs | ForEach-Object { if ($_ -match "\s") { "`"$_`"" } else { $_ } }) -join " "
Write-Host "Running: $commandStr" -ForegroundColor Green

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
        Write-Host "yt-dlp not found. Downloading the latest version for $os..." -ForegroundColor Yellow
        $downloadUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/$binaryName"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing
            if ($os -ne "windows") {
                & chmod +x $exePath
            }
            Write-Host "yt-dlp downloaded successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Failed to download yt-dlp. Please install it manually from https://github.com/yt-dlp/yt-dlp/releases" -ForegroundColor Red
            exit 1
        }
    } else {
        $exePath = "yt-dlp"
    }
}

$proc = Start-Process $exePath -ArgumentList $ytDlpArgs -NoNewWindow -Wait -PassThru
if ($proc) {
    exit $proc.ExitCode
}
