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

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb      = "RunAs"

    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
    catch {
        Write-Host "[-] Could not elevate. Run the script as Administrator manually." -ForegroundColor Red
    }
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
            $existingExclusions = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($existingExclusions -notcontains $DownloadPath) {
                Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop
            }
            Write-Host " [OK]" -ForegroundColor Green
            $success = $true
        }
    }
    catch {}

    if (-not $success) {
        try {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $regPath) {
                $existingValue = Get-ItemProperty -Path $regPath -Name $DownloadPath -ErrorAction SilentlyContinue
                if (-not $existingValue) {
                    New-ItemProperty -Path $regPath -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " [OK]" -ForegroundColor Green
                $success = $true
            }
        }
        catch {}
    }

    if (-not $success) {
        try {
            $namespace = "root\Microsoft\Windows\Defender"
            if (Get-WmiObject -Namespace $namespace -List -ErrorAction SilentlyContinue) {
                $defender = Get-WmiObject -Namespace $namespace -Class "MSFT_MpPreference" -ErrorAction Stop
                $defender.AddExclusionPath($DownloadPath)
                Write-Host " [OK]" -ForegroundColor Green
                $success = $true
            }
        }
        catch {}
    }

    if (-not $success) {
        Write-Host " [FAILED]" -ForegroundColor Red
    }

    return $success
}

$exclusionAdded = Add-DefenderExclusion

if (-not $exclusionAdded) {
    Write-Host "`n[!] Could not add automatic antivirus exclusion." -ForegroundColor Yellow
    Write-Host "[!] You might be running a 3rd party AV -- some files could get deleted." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# ─── Parallel download engine ──────────────────────────────────────────────────
# Uses RunspacePool (real OS threads). A synchronized hashtable carries status
# back to the main thread. The display loop only redraws a line when its state
# actually changes, eliminating all cursor-jump flicker.

$DownloadScript = {
    param($Url, $FileName, $ToolName, $DownloadPath, $StatusTable)

    $outputPath = Join-Path $DownloadPath $FileName
    $StatusTable[$ToolName] = "downloading"

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($Url, $outputPath)

        # Validate we got a real file (not an HTML error page)
        if ((Get-Item $outputPath -ErrorAction SilentlyContinue).Length -lt 1024) {
            throw "Downloaded file is too small -- likely an error page"
        }

        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, $extractPath)
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
        }

        $StatusTable[$ToolName] = "done"
    }
    catch {
        # Clean up partial/invalid file
        if (Test-Path $outputPath) { Remove-Item $outputPath -Force -ErrorAction SilentlyContinue }
        $StatusTable[$ToolName] = "failed"
    }
}

function Download-Tools-Parallel {
    param(
        [array]$Tools,
        [string]$CategoryName
    )

    Write-Host "`n[*] Downloading $CategoryName tools in parallel..." -ForegroundColor Cyan
    Write-Host ""

    # Shared thread-safe hashtable
    $statusTable  = [hashtable]::Synchronized(@{})
    $prevState    = @{}
    $toolOrder    = @()

    foreach ($tool in $Tools) {
        $statusTable[$tool.Name] = "queued"
        $prevState[$tool.Name]   = ""        # force first draw
        $toolOrder += $tool.Name
    }

    # Launch all runspaces simultaneously
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
        [void]$ps.AddArgument($DownloadPath)
        [void]$ps.AddArgument($statusTable)

        $runspaces += [PSCustomObject]@{
            Pipe   = $ps
            Handle = $ps.BeginInvoke()
            Name   = $tool.Name
        }
    }

    # ── Flicker-free live display ──────────────────────────────────────────────
    # Each tool gets a fixed line. We record the cursor row for each tool on the
    # first pass, then only jump back to that specific row when the state changes.
    # This avoids the "whole block redraw" that causes visible flicker/jumping.

    $lineMap     = @{}   # tool name -> console row
    $spinFrames  = @("|", "/", "-", "\")
    $spinIdx     = 0

    # Initial render — print every tool on its own line and record the row
    foreach ($name in $toolOrder) {
        $lineMap[$name] = [Console]::CursorTop
        Write-Host ("  [ ] " + $name.PadRight(28) + "  waiting...").PadRight(65) -ForegroundColor DarkGray
    }

    do {
        Start-Sleep -Milliseconds 120
        $spin    = $spinFrames[$spinIdx % 4]; $spinIdx++
        $savRow  = [Console]::CursorTop
        $savCol  = [Console]::CursorLeft

        foreach ($name in $toolOrder) {
            $state = $statusTable[$name]

            # Only rewrite the line if something changed (or it's still spinning)
            if ($state -eq "downloading" -or $state -ne $prevState[$name]) {
                $prevState[$name] = $state
                $label = $name.PadRight(28)

                [Console]::SetCursorPosition(0, $lineMap[$name])

                switch ($state) {
                    "queued"      {
                        Write-Host ("  [ ] $label  waiting...   ").PadRight(65) -ForegroundColor DarkGray
                    }
                    "downloading" {
                        Write-Host ("  $spin  $label  downloading...").PadRight(65) -ForegroundColor Yellow
                    }
                    "done"        {
                        Write-Host ("  [+] $label  done         ").PadRight(65) -ForegroundColor Green
                    }
                    "failed"      {
                        Write-Host ("  [X] $label  FAILED       ").PadRight(65) -ForegroundColor Red
                    }
                }
            }
        }

        # Restore cursor below the block so we don't jump the terminal
        [Console]::SetCursorPosition(0, $savRow)

        $pending = @($statusTable.Values | Where-Object { $_ -eq "queued" -or $_ -eq "downloading" })

    } while ($pending.Count -gt 0)

    # Move cursor to after the last tool line
    [Console]::SetCursorPosition(0, ($lineMap[$toolOrder[-1]] + 1))

    # Clean up
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

# Single sequential download (for the optional .NET SDK)
function Download-File {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$ToolName
    )

    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  [~] Downloading $ToolName..." -NoNewline

        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($Url, $outputPath)

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
        Write-Host " [FAILED]" -ForegroundColor Red
        return $false
    }
}

# ─── Tool definitions ──────────────────────────────────────────────────────────
#
#  HxD     -> https://mh-nexus.de/downloads/HxDSetup.zip          (official, confirmed)
#  BinText -> McAfee/Foundstone b2b CDN bintext303.zip             (official mirror)
#  FTK     -> Exterro public CDN 4.7.3.81                          (official build)

$zimmermanTools = @(
    @{ Name = "bstrings";         Url = "https://download.ericzimmermanstools.com/net9/bstrings.zip";         File = "bstrings.zip" },
    @{ Name = "TimelineExplorer"; Url = "https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip"; File = "TimelineExplorer.zip" }
)

$nirsoftTools = @(
    @{ Name = "FullEventLogView"; Url = "https://www.nirsoft.net/utils/fulleventlogview-x64.zip"; File = "fulleventlogview-x64.zip" }
)

$spokwnTools = @(
    @{ Name = "KernelLiveDumpTool"; Url = "https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File = "KernelLiveDumpTool.exe" }
)

$otherTools = @(
    @{ Name = "Everything Search"; Url = "https://www.voidtools.com/Everything-1.4.1.1032.x64-Setup.exe";                                   File = "Everything-1.4.1.1032.x64-Setup.exe" },
    @{ Name = "Hayabusa";          Url = "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x64.zip"; File = "hayabusa-3.8.0-win-x64.zip" },
    @{ Name = "HxD Hex Editor";    Url = "https://mh-nexus.de/downloads/HxDSetup.zip";                                                      File = "HxDSetup.zip" },
    @{ Name = "BinText";           Url = "http://b2b-download.mcafee.com/products/tools/foundstone/bintext303.zip";                          File = "bintext303.zip" },
    @{ Name = "FTK Imager";        Url = "https://d1kpmuwb7gvu1i.cloudfront.net/FTK-Imager/4.7.3.81/Exterro_FTK_Imager_(x64)-4.7.3.81.exe"; File = "FTK_Imager_4.7.3.81.exe" }
)

# ─── Menu ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "              Meow Fileless Downloader v1.2                " -ForegroundColor Cyan
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
                      -FileName "dotnet-sdk-9.0.306-win-x64.exe" `
                      -ToolName ".NET 9 SDK"
    }

} else {
    Write-Host "`n[*] Select categories to download:" -ForegroundColor Yellow

    $selected   = @()
    $needDotNet = $false

    $response = Read-Host "`nDownload Zimmerman's tools? (bstrings, TimelineExplorer) (Y/N)"
    if ($response -match '^[Yy]') {
        $selected   += $zimmermanTools
        $needDotNet  = $true
    }

    $response = Read-Host "`nDownload Nirsoft tools? (FullEventLogView) (Y/N)"
    if ($response -match '^[Yy]') { $selected += $nirsoftTools }

    $response = Read-Host "`nDownload Spokwn's tools? (KernelLiveDumpTool) (Y/N)"
    if ($response -match '^[Yy]') { $selected += $spokwnTools }

    $response = Read-Host "`nDownload other tools? (Everything, Hayabusa, HxD, BinText, FTK Imager) (Y/N)"
    if ($response -match '^[Yy]') { $selected += $otherTools }

    if ($selected.Count -gt 0) {
        Write-Host "`n[+] Launching $($selected.Count) download(s) simultaneously..." -ForegroundColor Green
        Download-Tools-Parallel -Tools $selected -CategoryName "Selected"
    } else {
        Write-Host "`n[!] Nothing selected. Bye!" -ForegroundColor Yellow
    }

    if ($needDotNet) {
        $runtimeResponse = Read-Host "`nInstall .NET 9 Runtime? (required for Zimmerman tools) (Y/N)"
        if ($runtimeResponse -match '^[Yy]') {
            Download-File -Url "https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-win-x64.exe" `
                          -FileName "dotnet-sdk-9.0.306-win-x64.exe" `
                          -ToolName ".NET 9 SDK"
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
