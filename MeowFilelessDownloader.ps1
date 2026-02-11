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
Write-Host "                  Made with love by Tonynoh <3" -ForegroundColor White
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
    Write-Host "[*] Adding Windows Defender exclusion for C:\MeowTools" -NoNewline
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
        if ($size -lt 1024) { throw "File too small" }

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

    Write-Host "`n[*] Downloading $CategoryName tools..." -ForegroundColor Cyan

    $statusTable = [hashtable]::Synchronized(@{})
    foreach ($tool in $Tools) {
        $statusTable[$tool.Name] = "queued"
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

    do {
        Start-Sleep -Milliseconds 1000
        $pending = @($statusTable.Values | Where-Object { $_ -eq "queued" -or $_ -eq "downloading" })
    } while ($pending.Count -gt 0)

    foreach ($r in $runspaces) {
        try { $r.Pipe.EndInvoke($r.Handle) } catch {}
        $r.Pipe.Dispose()
    }
    $pool.Close(); $pool.Dispose()

    Write-Host ""
    foreach ($tool in $Tools) {
        $state = $statusTable[$tool.Name]
        if ($state -eq "done") {
            Write-Host "  [+] $($tool.Name)" -ForegroundColor Green
        } else {
            Write-Host "  [X] $($tool.Name)" -ForegroundColor Red
        }
    }

    $success = @($statusTable.Values | Where-Object { $_ -eq "done" }).Count
    $color   = if ($success -eq $Tools.Count) { "Green" } else { "Yellow" }
    Write-Host ""
    Write-Host "[$CategoryName] $success/$($Tools.Count) downloaded successfully" -ForegroundColor $color
}

function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName)
    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  [~] Downloading $ToolName..." -NoNewline
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
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
    @{ Name = "BinText";           Url = "https://www.portablefreeware.com/download.php?dd=2506"; File = "BinText.zip"; Referer = "https://www.portablefreeware.com/index.php?id=2506" }
)

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "              Meow Fileless Downloader v3.0                                   " -ForegroundColor Cyan
Write-Host "              Tool drop folder : $DownloadPath                                " -ForegroundColor DarkCyan
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""

$installAllResponse = Read-Host "Download ALL tool categories? (Y/N)"
$installAll = $installAllResponse -match '^[Yy]'

if ($installAll) {
    Write-Host "`n[+] Launching downloads..." -ForegroundColor Green
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

    $r = Read-Host "`nDownload other tools? (Everything, Hayabusa, HxD, BinText) (Y/N)"
    if ($r -match '^[Yy]') { $selected += $otherTools }

    if ($selected.Count -gt 0) {
        Write-Host "`n[+] Launching downloads..." -ForegroundColor Green
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
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "[+] All done! Tools are located in: $DownloadPath" -ForegroundColor Cyan
Write-Host ""

# ════════════════════════════════════════════════════════════════════════════════
# FILELESS CHECKER
# ════════════════════════════════════════════════════════════════════════════════

$runChecker = Read-Host "Run FileLess System Checker? (Y/N)"
if ($runChecker -match '^[Yy]') {
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "                         FILELESS SYSTEM CHECKER                              " -ForegroundColor Magenta
    Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host ""

    # REGISTRY
    Write-Host "REGISTRY" -ForegroundColor Cyan
    
    $psLogging = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -ErrorAction SilentlyContinue
    Write-Host "  PowerShell Logging: " -NoNewline -ForegroundColor White
    if ($psLogging -and $psLogging.EnableScriptBlockLogging -eq 1) {
        Write-Host "Enabled" -ForegroundColor Green
    } else {
        Write-Host "Disabled" -ForegroundColor Red
    }

    $prefetch = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -ErrorAction SilentlyContinue
    Write-Host "  Prefetch Enabled: " -NoNewline -ForegroundColor White
    if ($prefetch -and $prefetch.EnablePrefetcher -ne 0) {
        Write-Host "Enabled" -ForegroundColor Green
    } else {
        Write-Host "Disabled" -ForegroundColor Red
    }

    # USN JOURNAL / EVENT LOGS
    Write-Host "`nUSN JOURNAL" -ForegroundColor Cyan
    
    $usnEvent = Get-WinEvent -LogName "Application" -FilterXPath "*[System[EventID=3079]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($usnEvent) {
        Write-Host "  USN Journal cleared at: " -NoNewline -ForegroundColor White
        Write-Host $usnEvent.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  USN Journal cleared at: No records found" -ForegroundColor Green
    }

    $clearEvent = Get-WinEvent -LogName "System" -FilterXPath "*[System[EventID=104 or EventID=1102]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($clearEvent) {
        Write-Host "  Event Logs cleared (ID: $($clearEvent.Id)) at: " -NoNewline -ForegroundColor White
        Write-Host $clearEvent.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  Event Logs cleared: No records found" -ForegroundColor Green
    }

    $serviceStartEvent = Get-WinEvent -LogName "System" -FilterXPath "*[System[EventID=6005]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($serviceStartEvent) {
        Write-Host "  Event Log Service started at: " -NoNewline -ForegroundColor White
        Write-Host $serviceStartEvent.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  Event Log Service started at: No records found" -ForegroundColor Green
    }

    # CONSOLE HOST HISTORY
    Write-Host "`nCONSOLE HOST HISTORY" -ForegroundColor Cyan
    
    $consoleHistoryPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    
    if (Test-Path $consoleHistoryPath) {
        $historyFile = Get-Item -Path $consoleHistoryPath -Force
        Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
        Write-Host $historyFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
        
        $attributes = $historyFile.Attributes
        Write-Host "  Attributes: " -NoNewline -ForegroundColor White
        if ($attributes -eq "Archive") {
            Write-Host "Normal" -ForegroundColor Green
        } else {
            Write-Host $attributes -ForegroundColor Yellow
        }
        
        $fileSize = $historyFile.Length
        Write-Host "  File Size: " -NoNewline -ForegroundColor White
        Write-Host "$([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor Yellow
    } else {
        Write-Host "  File not found: $consoleHistoryPath" -ForegroundColor Yellow
        Write-Host "  Note: PowerShell history may be disabled or never used" -ForegroundColor Gray
    }

    # SUSPICIOUS POWERSHELL COMMANDS
    Write-Host "`nSUSPICIOUS POWERSHELL COMMANDS" -ForegroundColor Cyan
    
    $suspiciousPatterns = @(
        "invoke-", "iex", "invoke-expression", "downloadstring",
        "downloadfile", "webclient", "bits", "bitstransfer",
        "curl", "wget", "powershell -enc", "frombase64string",
        "new-object", "start-process", "invoke-webrequest",
        "invoke-restmethod"
    )

    try {
        $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        
        $suspiciousCommands = @()
        $channels = @("Windows PowerShell", "Microsoft-Windows-PowerShell/Operational")
        
        foreach ($channel in $channels) {
            try {
                $events = Get-WinEvent -LogName $channel -ErrorAction SilentlyContinue | 
                    Where-Object { $_.TimeCreated -gt $bootTime } |
                    Select-Object -First 100

                foreach ($event in $events) {
                    $message = $event.Message
                    if ($message) {
                        $lowerMessage = $message.ToLower()
                        foreach ($pattern in $suspiciousPatterns) {
                            if ($lowerMessage -match $pattern) {
                                if ($suspiciousCommands -notcontains $message) {
                                    $suspiciousCommands += $message
                                }
                                break
                            }
                        }
                    }
                }
            } catch {}
        }

        if ($suspiciousCommands.Count -gt 0) {
            Write-Host "  Found $($suspiciousCommands.Count) suspicious commands since last boot:" -ForegroundColor Yellow
            $counter = 1
            foreach ($cmd in $suspiciousCommands | Select-Object -First 5) {
                Write-Host "`n  [#$counter] " -NoNewline -ForegroundColor White
                $preview = $cmd.Substring(0, [Math]::Min(150, $cmd.Length))
                if ($cmd.Length -gt 150) { $preview += "..." }
                Write-Host $preview -ForegroundColor Gray
                $counter++
            }
            if ($suspiciousCommands.Count -gt 5) {
                Write-Host "`n  ... and $($suspiciousCommands.Count - 5) more" -ForegroundColor Gray
            }
        } else {
            Write-Host "  No suspicious commands found since last boot" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Unable to check for suspicious commands" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "[+] FileLess Checker Complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "[+] Dm Me On Discord @tonyboy90_ if you got some shit to add." -ForegroundColor White
Write-Host ""
