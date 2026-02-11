Write-Host @"
███╗   ███╗███████╗ ██████╗ ██╗    ██╗        
████╗ ████║██╔════╝██╔═══██╗██║    ██║         
██╔████╔██║█████╗  ██║   ██║██║ █╗ ██║        
██║╚██╔╝██║██╔══╝  ██║   ██║██║███╗██║          
██║ ╚═╝ ██║███████╗╚██████╔╝╚███╔███╔╝   
╚═╝     ╚═╝╚══════╝ ╚═════╝  ╚══╝╚══╝    
"@ -ForegroundColor Magenta

Write-Host @"
███████╗██╗██╗     ███████╗██╗     ███████╗███████╗███████╗
██╔════╝██║██║     ██╔════╝██║     ██╔════╝██╔════╝██╔════╝
█████╗  ██║██║     █████╗  ██║     █████╗  ███████╗███████╗
██╔══╝  ██║██║     ██╔══╝  ██║     ██╔══╝  ╚════██║╚════██║
██║     ██║███████╗███████╗███████╗███████╗███████║███████║
╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝
"@ -ForegroundColor Cyan

Write-Host @"
██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗ 
██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
"@ -ForegroundColor Yellow

Write-Host ""
Write-Host "                     Made with love by Tonynoh <3" -ForegroundColor Magenta
Write-Host ""

# ─── Admin check ───────────────────────────────────────────────────────────────
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "[*] Restarting as Administrator..." -ForegroundColor Yellow

    $psi           = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb      = "RunAs"

    try   { [System.Diagnostics.Process]::Start($psi) | Out-Null; exit }
    catch { Write-Host "[-] Could not elevate. Run the script as Administrator manually." -ForegroundColor Red }
}

# ─── Output folder ─────────────────────────────────────────────────────────────
$DownloadPath = "C:\MeowTools"
if (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

# ─── Windows Defender exclusion ────────────────────────────────────────────────
function Add-DefenderExclusion {
    Write-Host "`n[*] Setting up antivirus exclusion..." -ForegroundColor Cyan
    Write-Host "[*] Adding Windows Defender exclusion for $DownloadPath" -NoNewline

    $success = $false
    try {
        if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
            $exc = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($exc -notcontains $DownloadPath) {
                Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop
            }
            Write-Host " [OK]" -ForegroundColor Green
            $success = $true
        }
    } catch {}

    if (-not $success) {
        try {
            $rp = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $rp) {
                if (-not (Get-ItemProperty -Path $rp -Name $DownloadPath -ErrorAction SilentlyContinue)) {
                    New-ItemProperty -Path $rp -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " [OK]" -ForegroundColor Green
                $success = $true
            }
        } catch {}
    }

    if (-not $success) { Write-Host " [FAILED]" -ForegroundColor Red }
    return $success
}

$exclusionAdded = Add-DefenderExclusion
if (-not $exclusionAdded) {
    Write-Host "`n[!] Could not add automatic antivirus exclusion." -ForegroundColor Yellow
    Write-Host "[!] You might be running a 3rd party AV -- some files could get deleted." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# ─── Core download function ────────────────────────────────────────────────────
# Uses System.Net.Http.HttpClient which:
#   - Follows all HTTP redirects automatically (crucial for GitHub, NirSoft)
#   - Lets us set any headers we need (Referer for NirSoft, User-Agent for all)
#   - Streams directly to disk without loading into RAM

Add-Type -AssemblyName System.Net.Http

function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutPath,
        [string]$Referer = ""
    )

    $handler                        = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect      = $true
    $handler.MaxAutomaticRedirections = 10

    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36")
    if ($Referer) {
        $client.DefaultRequestHeaders.Add("Referer", $Referer)
    }

    try {
        $response = $client.GetAsync($Url).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null

        $stream   = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $fileStream = [System.IO.File]::Create($OutPath)
        $stream.CopyTo($fileStream)
        $fileStream.Close()
        $stream.Close()
    }
    finally {
        $client.Dispose()
        $handler.Dispose()
    }
}

# ─── Parallel download engine ──────────────────────────────────────────────────

$DownloadScript = {
    param($Url, $FileName, $ToolName, $Referer, $DownloadPath, $StatusTable)

    $outputPath = Join-Path $DownloadPath $FileName
    $StatusTable[$ToolName] = "downloading"

    try {
        Add-Type -AssemblyName System.Net.Http

        $handler                          = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect        = $true
        $handler.MaxAutomaticRedirections = 10

        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36")
        if ($Referer) {
            $client.DefaultRequestHeaders.Add("Referer", $Referer)
        }

        $response = $client.GetAsync($Url).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null

        $stream     = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $fileStream = [System.IO.File]::Create($outputPath)
        $stream.CopyTo($fileStream)
        $fileStream.Close()
        $stream.Close()
        $client.Dispose()
        $handler.Dispose()

        # Sanity check: make sure we got an actual file, not an HTML error page
        $size = (Get-Item $outputPath -ErrorAction SilentlyContinue).Length
        if ($size -lt 2048) { throw "File too small ($size bytes) -- likely an error page" }

        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, $extractPath)
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
        }

        $StatusTable[$ToolName] = "done"
    }
    catch {
        if (Test-Path $outputPath) { Remove-Item $outputPath -Force -ErrorAction SilentlyContinue }
        $StatusTable[$ToolName] = "failed:$($_.Exception.Message)"
    }
}

function Download-Tools-Parallel {
    param(
        [array]$Tools,
        [string]$CategoryName
    )

    Write-Host "`n[*] Downloading $CategoryName tools in parallel..." -ForegroundColor Cyan
    Write-Host ""

    $statusTable = [hashtable]::Synchronized(@{})
    $prevState   = @{}
    $toolOrder   = @()

    foreach ($tool in $Tools) {
        $statusTable[$tool.Name] = "queued"
        $prevState[$tool.Name]   = ""
        $toolOrder += $tool.Name
    }

    $maxThreads = [Math]::Min($Tools.Count, 16)
    $pool       = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads)
    $pool.Open()

    $runspaces = @()
    foreach ($tool in $Tools) {
        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($DownloadScript)
        [void]$ps.AddArgument($tool.Url)
        [void]$ps.AddArgument($tool.File)
        [void]$ps.AddArgument($tool.Name)
        [void]$ps.AddArgument($(if ($tool.Referer) { $tool.Referer } else { "" }))
        [void]$ps.AddArgument($DownloadPath)
        [void]$ps.AddArgument($statusTable)

        $runspaces += [PSCustomObject]@{
            Pipe   = $ps
            Handle = $ps.BeginInvoke()
            Name   = $tool.Name
        }
    }

    # ── Flicker-free live display ──────────────────────────────────────────────
    $spinFrames = @("|", "/", "-", "\")
    $spinIdx    = 0
    $lineMap    = @{}

    foreach ($name in $toolOrder) {
        $lineMap[$name] = [Console]::CursorTop
        Write-Host ("  [ ] " + $name.PadRight(28) + "  waiting...").PadRight(65) -ForegroundColor DarkGray
    }

    do {
        Start-Sleep -Milliseconds 120
        $spin = $spinFrames[$spinIdx % 4]; $spinIdx++

        foreach ($name in $toolOrder) {
            $state = $statusTable[$name]
            $stateKey = if ($state -like "failed:*") { "failed" } else { $state }

            if ($stateKey -eq "downloading" -or $stateKey -ne $prevState[$name]) {
                $prevState[$name] = $stateKey
                $label = $name.PadRight(28)

                [Console]::SetCursorPosition(0, $lineMap[$name])
                switch ($stateKey) {
                    "queued"      { Write-Host ("  [ ] $label  waiting...   ").PadRight(65) -ForegroundColor DarkGray }
                    "downloading" { Write-Host ("  $spin  $label  downloading...").PadRight(65) -ForegroundColor Yellow  }
                    "done"        { Write-Host ("  [+] $label  done         ").PadRight(65) -ForegroundColor Green    }
                    "failed"      { Write-Host ("  [X] $label  FAILED       ").PadRight(65) -ForegroundColor Red      }
                }
            }
        }

        [Console]::SetCursorPosition(0, ($lineMap[$toolOrder[-1]] + 1))

        $pending = @($statusTable.Values | Where-Object { $_ -eq "queued" -or $_ -eq "downloading" })

    } while ($pending.Count -gt 0)

    foreach ($r in $runspaces) {
        try { $r.Pipe.EndInvoke($r.Handle) } catch {}
        $r.Pipe.Dispose()
    }
    $pool.Close()
    $pool.Dispose()

    $success = @($statusTable.Values | Where-Object { $_ -eq "done" }).Count
    $total   = $Tools.Count
    $color   = if ($success -eq $total) { "Green" } else { "Yellow" }
    Write-Host ""
    Write-Host "[$CategoryName] $success/$total downloaded successfully" -ForegroundColor $color
}

function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName, [string]$Referer = "")

    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  [~] Downloading $ToolName..." -NoNewline
        Invoke-Download -Url $Url -OutPath $outputPath -Referer $Referer

        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, $extractPath)
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host " [DONE]" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " [FAILED] -- $_" -ForegroundColor Red
        return $false
    }
}

# ─── Tool definitions ──────────────────────────────────────────────────────────
#
#  Each entry can have an optional "Referer" field for sites that check it.
#
#  NirSoft  -> requires Referer header matching their domain
#  GitHub   -> multiple redirects, handled by HttpClient AllowAutoRedirect
#  BinText  -> GitHub mirror (mfput/McAfee-Tools) - McAfee CDN is offline
#  FTK      -> Exterro CloudFront direct link (confirmed from release notes PDF URL pattern)

$zimmermanTools = @(
    @{ Name = "bstrings";         Url = "https://download.ericzimmermanstools.com/net9/bstrings.zip";         File = "bstrings.zip";         Referer = "" },
    @{ Name = "TimelineExplorer"; Url = "https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip"; File = "TimelineExplorer.zip"; Referer = "" }
)

$nirsoftTools = @(
    @{ Name = "FullEventLogView"; Url = "https://www.nirsoft.net/utils/fulleventlogview-x64.zip"; File = "fulleventlogview-x64.zip"; Referer = "https://www.nirsoft.net/utils/full_event_log_view.html" }
)

$spokwnTools = @(
    @{ Name = "KernelLiveDumpTool"; Url = "https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File = "KernelLiveDumpTool.exe"; Referer = "" }
)

$otherTools = @(
    @{ Name = "Everything Search"; Url = "https://www.voidtools.com/Everything-1.4.1.1032.x64-Setup.exe";                                                         File = "Everything-1.4.1.1032.x64-Setup.exe";   Referer = "https://www.voidtools.com/downloads/" },
    @{ Name = "Hayabusa";          Url = "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x64.zip";                       File = "hayabusa-3.8.0-win-x64.zip";            Referer = "" },
    @{ Name = "HxD Hex Editor";    Url = "https://mh-nexus.de/downloads/HxDSetup.zip";                                                                            File = "HxDSetup.zip";                          Referer = "https://mh-nexus.de/en/hxd/" },
    @{ Name = "BinText";           Url = "https://github.com/mfput/McAfee-Tools/raw/main/bintext303.zip";                                                         File = "bintext303.zip";                        Referer = "" },
    @{ Name = "FTK Imager";        Url = "https://d1kpmuwb7gvu1i.cloudfront.net/FTK-Imager/4.7.3.81/Exterro_FTK_Imager_%28x64%29-4.7.3.81.exe";                  File = "FTK_Imager_4.7.3.81.exe";               Referer = "https://www.exterro.com/ftk-product-downloads/ftk-imager-4-7-3-81" }
)

# ─── Menu ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "              Meow Fileless Downloader v1.3                " -ForegroundColor Cyan
Write-Host "              Tool drop folder : $DownloadPath             " -ForegroundColor DarkCyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""

$installAllResponse = Read-Host "Download ALL tool categories? (Y/N)"
$installAll = $installAllResponse -match '^[Yy]'

if ($installAll) {
    Write-Host "`n[+] Launching all downloads simultaneously..." -ForegroundColor Green
    $allTools = $zimmermanTools + $nirsoftTools + $spokwnTools + $otherTools
    Download-Tools-Parallel -Tools $allTools -CategoryName "All"

    $runtimeResponse = Read-Host "`nInstall .NET 9 Runtime? (required for Zimmerman tools) (Y/N)"
    if ($runtimeResponse -match '^[Yy]') {
        Download-File -Url "https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-win-x64.exe" `
                      -FileName "dotnet-sdk-9.0.306-win-x64.exe" -ToolName ".NET 9 SDK"
    }

} else {
    Write-Host "`n[*] Select categories to download:" -ForegroundColor Yellow
    $selected   = @()
    $needDotNet = $false

    $r = Read-Host "`nDownload Zimmerman's tools? (bstrings, TimelineExplorer) (Y/N)"
    if ($r -match '^[Yy]') { $selected += $zimmermanTools; $needDotNet = $true }

    $r = Read-Host "`nDownload Nirsoft tools? (FullEventLogView) (Y/N)"
    if ($r -match '^[Yy]') { $selected += $nirsoftTools }

    $r = Read-Host "`nDownload Spokwn's tools? (KernelLiveDumpTool) (Y/N)"
    if ($r -match '^[Yy]') { $selected += $spokwnTools }

    $r = Read-Host "`nDownload other tools? (Everything, Hayabusa, HxD, BinText, FTK Imager) (Y/N)"
    if ($r -match '^[Yy]') { $selected += $otherTools }

    if ($selected.Count -gt 0) {
        Write-Host "`n[+] Launching $($selected.Count) download(s) simultaneously..." -ForegroundColor Green
        Download-Tools-Parallel -Tools $selected -CategoryName "Selected"
    } else {
        Write-Host "`n[!] Nothing selected. Bye!" -ForegroundColor Yellow
    }

    if ($needDotNet) {
        $rr = Read-Host "`nInstall .NET 9 Runtime? (required for Zimmerman tools) (Y/N)"
        if ($rr -match '^[Yy]') {
            Download-File -Url "https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-win-x64.exe" `
                          -FileName "dotnet-sdk-9.0.306-win-x64.exe" -ToolName ".NET 9 SDK"
        }
    }
}

# ─── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "[+] All done! Hit up @Tonynoh if you got ideas for tools to add." -ForegroundColor Magenta
Write-Host "[+] Tools are located in: $DownloadPath" -ForegroundColor Cyan
Write-Host ""
