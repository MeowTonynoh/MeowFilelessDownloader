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
Write-Host "                  Made with love by Tonynoh <3" -ForegroundColor Magenta
Write-Host ""

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "[*] Restarting as Administrator..." -ForegroundColor Yellow
    $psi           = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb      = "RunAs"
    try   { [System.Diagnostics.Process]::Start($psi) | Out-Null; exit }
    catch { Write-Host "[-] Could not elevate. Run as Administrator manually." -ForegroundColor Red }
}

$DownloadPath = "C:\MeowTools"
if (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

function Add-DefenderExclusion {
    Write-Host "`n[*] Setting up antivirus exclusion..." -ForegroundColor Cyan
    Write-Host "[*] Adding Windows Defender exclusion for $DownloadPath" -NoNewline
    $success = $false
    try {
        if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
            $exc = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($exc -notcontains $DownloadPath) { Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop }
            Write-Host " [OK]" -ForegroundColor Green; $success = $true
        }
    } catch {}
    if (-not $success) {
        try {
            $rp = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $rp) {
                if (-not (Get-ItemProperty -Path $rp -Name $DownloadPath -ErrorAction SilentlyContinue)) {
                    New-ItemProperty -Path $rp -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " [OK]" -ForegroundColor Green; $success = $true
            }
        } catch {}
    }
    if (-not $success) { Write-Host " [FAILED]" -ForegroundColor Red }
    return $success
}

$exclusionAdded = Add-DefenderExclusion
if (-not $exclusionAdded) {
    Write-Host "`n[!] Could not add antivirus exclusion -- 3rd party AV may delete files." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

$DownloadScript = {
    param($Url, $FileName, $ToolName, $Referer, $DownloadPath, $StatusTable)

    $outputPath = Join-Path $DownloadPath $FileName
    $StatusTable[$ToolName] = "downloading"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        }
        if ($Referer) { $headers["Referer"] = $Referer }

        $ProgressPreference = 'SilentlyContinue'
        
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -Headers $headers `
            -UseBasicParsing -MaximumRedirection 10 -TimeoutSec 180 -ErrorAction Stop

        $size = (Get-Item $outputPath -ErrorAction SilentlyContinue).Length
        if ($size -lt 1024) { throw "File too small ($size bytes)" }

        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, $extractPath)
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
        }

        $StatusTable[$ToolName] = "done"
    }
    catch {
        if (Test-Path $outputPath) { Remove-Item $outputPath -Force -ErrorAction SilentlyContinue }
        $StatusTable[$ToolName] = "failed"
    }
}

function Download-Tools-Parallel {
    param([array]$Tools, [string]$CategoryName)

    Write-Host "`n[*] Downloading $CategoryName tools in parallel..." -ForegroundColor Cyan
    Write-Host ""

    $statusTable = [hashtable]::Synchronized(@{})
    $toolOrder   = @()
    foreach ($tool in $Tools) {
        $statusTable[$tool.Name] = "queued"
        $toolOrder += $tool.Name
    }

    $pool = [RunspaceFactory]::CreateRunspacePool(1, 6)
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
        $runspaces += [PSCustomObject]@{ Pipe = $ps; Handle = $ps.BeginInvoke(); Name = $tool.Name }
    }

    $ESC        = [char]27
    $spinFrames = @("|", "/", "-", "\")
    $spinIdx    = 0
    $n          = $toolOrder.Count

    foreach ($name in $toolOrder) {
        Write-Host ("  [ ] " + $name.PadRight(28) + "  waiting...").PadRight(68) -ForegroundColor DarkGray
    }

    do {
        Start-Sleep -Milliseconds 600

        $spin = $spinFrames[$spinIdx % 4]
        $spinIdx++

        [Console]::Write("$ESC[${n}A")

        foreach ($name in $toolOrder) {
            $state = $statusTable[$name]
            $label = $name.PadRight(28)

            switch ($state) {
                "queued"      { Write-Host ("  [ ] $label  waiting...   ").PadRight(68) -ForegroundColor DarkGray }
                "downloading" { Write-Host ("  $spin  $label  downloading...").PadRight(68) -ForegroundColor Yellow  }
                "done"        { Write-Host ("  [+] $label  done         ").PadRight(68) -ForegroundColor Green    }
                default       { Write-Host ("  [X] $label  FAILED       ").PadRight(68) -ForegroundColor Red      }
            }
        }

        $pending = @($statusTable.Values | Where-Object { $_ -eq "queued" -or $_ -eq "downloading" })

    } while ($pending.Count -gt 0)

    foreach ($r in $runspaces) {
        try { $r.Pipe.EndInvoke($r.Handle) } catch {}
        $r.Pipe.Dispose()
    }
    $pool.Close(); $pool.Dispose()

    $success = @($statusTable.Values | Where-Object { $_ -eq "done" }).Count
    $color   = if ($success -eq $Tools.Count) { "Green" } else { "Yellow" }
    Write-Host ""
    Write-Host "[$CategoryName] $success/$($Tools.Count) downloaded successfully" -ForegroundColor $color
}

function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName, [string]$Referer = "")
    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  [~] Downloading $ToolName..." -NoNewline
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
        if ($Referer) { $headers["Referer"] = $Referer }
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -Headers $headers `
            -UseBasicParsing -MaximumRedirection 10 -TimeoutSec 180 -ErrorAction Stop
        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, $extractPath)
            Remove-Item $outputPath -Force
        }
        Write-Host " [DONE]" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        return $false
    }
}

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
    @{ Name = "Everything Search"; Url = "https://www.voidtools.com/Everything-1.4.1.1032.x64-Setup.exe"; File = "Everything-1.4.1.1032.x64-Setup.exe"; Referer = "" },
    @{ Name = "Hayabusa";          Url = "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x64.zip"; File = "hayabusa-3.8.0-win-x64.zip"; Referer = "" },
    @{ Name = "HxD Hex Editor";    Url = "https://mh-nexus.de/downloads/HxDSetup.zip"; File = "HxDSetup.zip"; Referer = "" },
    @{ Name = "BinText";           Url = "http://packetstormsecurity.com/files/download/23823/bintext.zip"; File = "bintext.zip"; Referer = "" },
    @{ Name = "FTK Imager";        Url = "https://go.exterro.com/l/43312/2023-05-03/fc4b78"; File = "FTK_Imager_4.7.exe"; Referer = "" }
)

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "              Meow Fileless Downloader v1.5                " -ForegroundColor Cyan
Write-Host "              Tool drop folder : $DownloadPath             " -ForegroundColor DarkCyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""

$installAllResponse = Read-Host "Download ALL tool categories? (Y/N)"
$installAll = $installAllResponse -match '^[Yy]'

if ($installAll) {
    Write-Host "`n[+] Launching all downloads simultaneously..." -ForegroundColor Green
    Download-Tools-Parallel -Tools ($zimmermanTools + $nirsoftTools + $spokwnTools + $otherTools) -CategoryName "All"

    $r = Read-Host "`nInstall .NET 9 Runtime? (required for Zimmerman tools) (Y/N)"
    if ($r -match '^[Yy]') {
        Download-File -Url "https://download.visualstudio.microsoft.com/download/pr/c511a58c-0aad-48d1-a401-f4f0ba2ba65e/00f03228c7bcb2ed1fc9e0b87c78bc0e/dotnet-sdk-9.0.101-win-x64.exe" `
                      -FileName "dotnet-sdk-9.0.101-win-x64.exe" -ToolName ".NET 9 SDK"
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
            Download-File -Url "https://download.visualstudio.microsoft.com/download/pr/c511a58c-0aad-48d1-a401-f4f0ba2ba65e/00f03228c7bcb2ed1fc9e0b87c78bc0e/dotnet-sdk-9.0.101-win-x64.exe" `
                          -FileName "dotnet-sdk-9.0.101-win-x64.exe" -ToolName ".NET 9 SDK"
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "[+] All done! dm me on discord @tonybnoy90_ if you got ideas for some shit to add." -ForegroundColor Magenta
Write-Host "[+] Tools are located in: $DownloadPath" -ForegroundColor Cyan
Write-Host ""
