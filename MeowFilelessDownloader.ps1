[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$Banner = @"

  ███╗   ███╗███████╗ ██████╗ ██╗    ██╗
  ████╗ ████║██╔════╝██╔═══██╗██║    ██║
  ██╔████╔██║█████╗  ██║   ██║██║ █╗ ██║
  ██║╚██╔╝██║██╔══╝  ██║   ██║██║███╗██║
  ██║ ╚═╝ ██║███████╗╚██████╔╝╚███╔███╔╝
  ╚═╝     ╚═╝╚══════╝ ╚═════╝  ╚══╝╚══╝

  ███████╗██╗██╗     ███████╗██╗     ███████╗███████╗███████╗
  ██╔════╝██║██║     ██╔════╝██║     ██╔════╝╚══███╔╝██╔════╝
  █████╗  ██║██║     █████╗  ██║     █████╗    ███╔╝ ███████╗
  ██╔══╝  ██║██║     ██╔══╝  ██║     ██╔══╝   ███╔╝  ╚════██║
  ██║     ██║███████╗███████╗███████╗███████╗███████╗███████║
  ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝

  ██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ███████╗
  ██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔════╝
  ██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║█████╗
  ██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║██╔══╝
  ██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║███████╗
  ╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝

                         \    /\
                          )  ( ')
                         (  /  )
                          \(__)|

"@

Write-Host $Banner -ForegroundColor Cyan
Write-Host ""
Write-Host "                Made with " -ForegroundColor Gray -NoNewline
Write-Host "♥ " -ForegroundColor Red -NoNewline
Write-Host "by " -ForegroundColor Gray -NoNewline
Write-Host "MeowTonynoh" -ForegroundColor Cyan
Write-Host ""
Write-Host ("━" * 76) -ForegroundColor DarkCyan
Write-Host

# Check for Administrator privileges
$isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║           ADMINISTRATOR PRIVILEGES REQUIRED       ║" -ForegroundColor Red
    Write-Host "║     Please run this script as Administrator!      ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Download directory
$DownloadPath = "C:\MeowTools"
if (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

Write-Host "📁 Download directory: " -ForegroundColor Cyan -NoNewline
Write-Host "$DownloadPath" -ForegroundColor White
Write-Host ""

# Windows Defender Exclusion
function Add-DefenderExclusion {
    Write-Host "🛡️  Setting up antivirus exclusion..." -ForegroundColor Cyan
    Write-Host "   Adding Windows Defender exclusion for " -NoNewline
    Write-Host "$DownloadPath" -ForegroundColor White -NoNewline
    
    $success = $false
    
    try {
        if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
            $existingExclusions = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($existingExclusions -notcontains $DownloadPath) {
                Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop
            }
            Write-Host " ✓" -ForegroundColor Green
            $success = $true
        }
    }
    catch {
        # Try alternative methods
    }
    
    if (-not $success) {
        try {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $regPath) {
                $existingValue = Get-ItemProperty -Path $regPath -Name $DownloadPath -ErrorAction SilentlyContinue
                if (-not $existingValue) {
                    New-ItemProperty -Path $regPath -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " ✓" -ForegroundColor Green
                $success = $true
            }
        }
        catch {
            # Continue
        }
    }
    
    if (-not $success) {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "   Could not add automatic antivirus exclusion" -ForegroundColor Yellow
        Write-Host "   You might be using 3rd party antivirus" -ForegroundColor Yellow
    }
    
    Write-Host ""
    return $success
}

Add-DefenderExclusion

# Download function
function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName)
    
    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  ⬇️  Downloading " -NoNewline
        Write-Host "$ToolName" -ForegroundColor White -NoNewline
        
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -UserAgent "PowerShell" -UseBasicParsing | Out-Null
        
        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Expand-Archive -Path $outputPath -DestinationPath $extractPath -Force | Out-Null
            Remove-Item $outputPath -Force | Out-Null
        }
        
        Write-Host " ✓" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor DarkGray
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

# Tools to download
$tools = @(
    @{ Name="bstrings"; Url="https://download.ericzimmermanstools.com/net9/bstrings.zip"; File="bstrings.zip" },
    @{ Name="FTK Imager"; Url="https://d1uxzfveuy41n0.cloudfront.net/AccessData_FTK_Imager_3.1.1.exe"; File="FTK_Imager_3.1.1.exe" },
    @{ Name="FullEventLogView"; Url="https://www.nirsoft.net/utils/fulleventlogview-x64.zip"; File="fulleventlogview-x64.zip" },
    @{ Name="Everything Search"; Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="Everything-1.4.1.1029.x86-Setup.exe" },
    @{ Name="KernelLiveDumpTool"; Url="https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File="KernelLiveDumpTool.exe" },
    @{ Name="Hayabusa"; Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x64.zip"; File="hayabusa-3.8.0-win-x64.zip" },
    @{ Name="Timeline Explorer"; Url="https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip"; File="TimelineExplorer.zip" },
    @{ Name="HxD Hex Editor"; Url="https://mh-nexus.de/downloads/HxDSetup.zip"; File="HxDSetup.zip" },
    @{ Name="BinText"; Url="https://download1511.mediafire.com/6rq5ggzr3rqgj0txqMBe5qYQVRp-LyUYQGdOCcxVG2SqFPIRk3GkMo7r3T9T5k8L7LvO_d8KhZlqcYz8QwWwHnWAC-xzJDQPzUvl_jElO_jNBpjF-WM7CgYKAH6kBQGeBbLBlrMFd_BhpT1-v26WsHCsjpf8NJ-S5yoXQOYKqLRr/yfvhfmyf08yd7k7/BinText.zip"; File="BinText.zip" }
)

Write-Host "🔧 DOWNLOADING FORENSIC TOOLS" -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray
Write-Host ""

$successCount = 0
foreach ($tool in $tools) {
    if (Download-File -Url $tool.Url -FileName $tool.File -ToolName $tool.Name) {
        $successCount++
    }
}

Write-Host ""
Write-Host ("─" * 76) -ForegroundColor DarkGray
Write-Host "✅ Downloaded " -NoNewline -ForegroundColor Green
Write-Host "$successCount/$($tools.Count) " -ForegroundColor White -NoNewline
Write-Host "tools successfully" -ForegroundColor Green
Write-Host ""

# Cool Checker Section
Write-Host ("━" * 76) -ForegroundColor Blue
Write-Host ""
Write-Host "🔍 SYSTEM INTEGRITY CHECKER" -ForegroundColor Cyan
Write-Host ""
Write-Host ("━" * 76) -ForegroundColor Blue
Write-Host ""

# Console Host History
Write-Host "📝 CONSOLE HOST HISTORY" -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray

$consoleHistoryPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"

if (Test-Path $consoleHistoryPath) {
    $historyFile = Get-Item -Path $consoleHistoryPath -Force
    Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
    Write-Host $historyFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
    
    $attributes = $historyFile.Attributes
    if ($attributes -ne "Archive") {
        Write-Host "  Attributes: " -NoNewline -ForegroundColor White
        Write-Host $attributes -ForegroundColor Yellow
    } else {
        Write-Host "  Attributes: " -NoNewline -ForegroundColor White
        Write-Host "Normal" -ForegroundColor Green
    }
    
    $fileSize = $historyFile.Length
    Write-Host "  File Size: " -NoNewline -ForegroundColor White
    Write-Host "$([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor Yellow
} else {
    Write-Host "  File not found" -ForegroundColor Yellow
    Write-Host "  Note: PowerShell history may be disabled or never used" -ForegroundColor Gray
}

Write-Host ""

# Event Logs
Write-Host "📋 EVENT LOGS" -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray

function Check-EventLog {
    param ($logName, $eventID, $message)
    $event = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$eventID]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($event) {
        Write-Host "  $message at: " -NoNewline -ForegroundColor White
        Write-Host $event.TimeCreated.ToString("MM/dd HH:mm:ss") -ForegroundColor Yellow
    } else {
        Write-Host "  $message " -NoNewline -ForegroundColor White
        Write-Host "No records found" -ForegroundColor Green
    }
}

function Check-RecentEventLog {
    param ($logName, $eventIDs, $message)
    $event = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$($eventIDs -join ' or EventID=')]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($event) {
        Write-Host "  $message (ID: $($event.Id)) at: " -NoNewline -ForegroundColor White
        Write-Host $event.TimeCreated.ToString("MM/dd HH:mm:ss") -ForegroundColor Yellow
    } else {
        Write-Host "  $message " -NoNewline -ForegroundColor White
        Write-Host "No records found" -ForegroundColor Green
    }
}

Check-EventLog "Application" 3079 "USN Journal cleared"
Check-RecentEventLog "System" @(104, 1102) "Event Logs cleared"
Check-EventLog "System" 1074 "Last PC Shutdown"
Check-EventLog "Security" 4616 "System time changed"
Check-EventLog "System" 6005 "Event Log Service started"

Write-Host ""

# Registry
Write-Host "📂 REGISTRY" -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray

$settings = @(
    @{ Name = "CMD"; Path = "HKCU:\Software\Policies\Microsoft\Windows\System"; Key = "DisableCMD"; Warning = "Disabled"; Safe = "Available" },
    @{ Name = "PowerShell Logging"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"; Key = "EnableScriptBlockLogging"; Warning = "Disabled"; Safe = "Enabled" }
)

foreach ($s in $settings) {
    $status = Get-ItemProperty -Path $s.Path -Name $s.Key -ErrorAction SilentlyContinue
    Write-Host "  " -NoNewline
    if ($status -and $status.$($s.Key) -eq 0) {
        Write-Host "$($s.Name): " -NoNewline -ForegroundColor White
        Write-Host "$($s.Warning)" -ForegroundColor Red
    } else {
        Write-Host "$($s.Name): " -NoNewline -ForegroundColor White
        Write-Host "$($s.Safe)" -ForegroundColor Green
    }
}

Write-Host ""

# Service Status
Write-Host "⚙️  SERVICE STATUS" -ForegroundColor Cyan
Write-Host ("─" * 76) -ForegroundColor DarkGray

$services = @(
    @{Name = "EventLog"; DisplayName = "Windows Event Log"}
)

foreach ($svc in $services) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq "Running") {
            $displayName = $service.DisplayName
            if ($displayName.Length -gt 40) {
                $displayName = $displayName.Substring(0, 37) + "..."
            }
            Write-Host "  " -NoNewline
            Write-Host "$($svc.Name)" -ForegroundColor Green -NoNewline
            Write-Host " " * (13 - $svc.Name.Length) -NoNewline
            Write-Host "$displayName" -ForegroundColor White -NoNewline
            
            try {
                $process = Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'" | Select-Object ProcessId
                if ($process.ProcessId -gt 0) {
                    $proc = Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
                    if ($proc) {
                        Write-Host " | " -NoNewline -ForegroundColor Gray
                        Write-Host $proc.StartTime.ToString("HH:mm:ss") -ForegroundColor Yellow
                    } else {
                        Write-Host " | N/A" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host " | N/A" -ForegroundColor Yellow
                }
            } catch {
                Write-Host " | N/A" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  $($svc.Name) - " -NoNewline -ForegroundColor Red
            Write-Host "$($service.Status)" -ForegroundColor Red
        }
    } else {
        Write-Host "  $($svc.Name) - " -NoNewline -ForegroundColor Yellow
        Write-Host "Not Found" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host ("━" * 76) -ForegroundColor Blue
Write-Host ""
Write-Host "  ✨ Download and check complete! Thanks for using Meow Fileless Downloader 🐱" -ForegroundColor Cyan
Write-Host ""
Write-Host "  👤 Created by: " -ForegroundColor White -NoNewline
Write-Host "🌟 " -ForegroundColor Cyan -NoNewline
Write-Host "Tonynoh" -ForegroundColor Cyan
Write-Host "  📱 My Socials: " -ForegroundColor White -NoNewline
Write-Host "💬 " -ForegroundColor Blue -NoNewline
Write-Host "Discord  : " -ForegroundColor Blue -NoNewline
Write-Host "tonyboy90_" -ForegroundColor Blue
Write-Host "                 " -NoNewline
Write-Host "🔗 " -ForegroundColor DarkGray -NoNewline
Write-Host "GitHub   : " -ForegroundColor DarkGray -NoNewline
Write-Host "https://github.com/MeowTonynoh" -ForegroundColor DarkGray
Write-Host "                 " -NoNewline
Write-Host "🎥 " -ForegroundColor Red -NoNewline
Write-Host "YouTube  : " -ForegroundColor Red -NoNewline
Write-Host "tonynoh-07" -ForegroundColor Red
Write-Host ""
Write-Host ("━" * 76) -ForegroundColor Blue
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")