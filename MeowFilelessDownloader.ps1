Write-Host @"
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
███████╗██╗██╗     ███████╗██╗     ███████╗███████╗███████╗
██╔════╝██║██║     ██╔════╝██║     ██╔════╝╚══███╔╝██╔════╝
█████╗  ██║██║     █████╗  ██║     █████╗    ███╔╝ ███████╗
██╔══╝  ██║██║     ██╔══╝  ██║     ██╔══╝   ███╔╝  ╚════██║
██║     ██║███████╗███████╗███████╗███████╗███████╗███████║
╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝
 ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗
██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝
██║     ███████║█████╗  ██║     █████╔╝
██║     ██╔══██║██╔══╝  ██║     ██╔═██╗
╚██████╗██║  ██║███████╗╚██████╗██║  ██╗
 ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝
"@ -ForegroundColor Magenta

Write-Host "                          Meow Fileless Checker" -ForegroundColor Cyan
Write-Host "                          Made with love by MeowTonyNoh<3" -ForegroundColor Cyan
Write-Host ""

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Restarting as Administrator" -ForegroundColor Yellow
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb = "RunAs"
    
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
    catch {
        Write-Host "no admin" -ForegroundColor Red
    }
}

$DownloadPath = "C:\MeowTools"
if (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

function Add-DefenderExclusion {
    Write-Host "`nSetting up antivirus exclusion" -ForegroundColor Cyan
    Write-Host "Adding Windows Defender exclusion for $DownloadPath" -NoNewline
    
    $success = $false
    
    try {
        if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
            $existingExclusions = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($existingExclusions -notcontains $DownloadPath) {
                Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop
            }
            Write-Host " Success" -ForegroundColor Green
            $success = $true
        }
    }
    catch {
      
    }
    
    if (-not $success) {
        try {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $regPath) {
                $existingValue = Get-ItemProperty -Path $regPath -Name $DownloadPath -ErrorAction SilentlyContinue
                if (-not $existingValue) {
                    New-ItemProperty -Path $regPath -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " Success" -ForegroundColor Green
                $success = $true
            }
        }
        catch {
           
        }
    }
    
    if (-not $success) {
        try {
            $namespace = "root\Microsoft\Windows\Defender"
            if (Get-WmiObject -Namespace $namespace -List -ErrorAction SilentlyContinue) {
                $defender = Get-WmiObject -Namespace $namespace -Class "MSFT_MpPreference" -ErrorAction Stop
                $defender.AddExclusionPath($DownloadPath)
                Write-Host " Success" -ForegroundColor Green
                $success = $true
            }
        }
        catch {
           
        }
    }
    
    if (-not $success) {
        Write-Host " Failed" -ForegroundColor Red
    }
    
    return $success
}

$exclusionAdded = Add-DefenderExclusion

if (-not $exclusionAdded) {
    Write-Host "`nCould not add automatic antivirus exclusion, you are prolly using some 3rd party av." -ForegroundColor Yellow
    Write-Host "`nContinuing with downloads (some might be deleted)" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName)
    
    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  Downloading $ToolName" -NoNewline
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -UserAgent "PowerShell" -UseBasicParsing | Out-Null
        
        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Expand-Archive -Path $outputPath -DestinationPath $extractPath -Force | Out-Null
            Remove-Item $outputPath -Force | Out-Null
        }
        Write-Host " Done" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

function Download-Tools {
    param([array]$Tools, [string]$CategoryName)
    
    $successCount = 0
    
    Write-Host "`nDownloading $CategoryName tools" -ForegroundColor Cyan
    foreach ($tool in $Tools) {
        if (Download-File -Url $tool.Url -FileName $tool.File -ToolName $tool.Name) {
            $successCount++
        }
    }
    
    Write-Host ($CategoryName + ": " + $successCount + "/" + $Tools.Count + " tools downloaded successfully") -ForegroundColor Cyan
}

$forensicTools = @(
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

Download-Tools -Tools $forensicTools -CategoryName "Forensic"

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "           MEOW FILELESS CHECKER STARTING        " -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

# Console Host History
Write-Host "CONSOLE HOST HISTORY" -ForegroundColor Cyan
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
        Write-Host "  Attributes: Normal" -ForegroundColor Green
    }
    
    $fileSize = $historyFile.Length
    Write-Host "  File Size: " -NoNewline -ForegroundColor White
    Write-Host "$([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor Yellow
} else {
    Write-Host "  File not found" -ForegroundColor Yellow
}

Write-Host ""

# Event Logs
Write-Host "EVENT LOGS" -ForegroundColor Cyan

function Check-EventLog {
    param ($logName, $eventID, $message)
    $event = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$eventID]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($event) {
        Write-Host "  $message at: " -NoNewline -ForegroundColor White
        Write-Host $event.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  $message - " -NoNewline -ForegroundColor White
        Write-Host "No records found" -ForegroundColor Green
    }
}

function Check-RecentEventLog {
    param ($logName, $eventIDs, $message)
    $event = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$($eventIDs -join ' or EventID=')]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($event) {
        Write-Host "  $message (ID: $($event.Id)) at: " -NoNewline -ForegroundColor White
        Write-Host $event.TimeCreated.ToString("MM/dd HH:mm") -ForegroundColor Yellow
    } else {
        Write-Host "  $message - " -NoNewline -ForegroundColor White
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
Write-Host "REGISTRY" -ForegroundColor Cyan

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
Write-Host "SERVICE STATUS" -ForegroundColor Cyan

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
            Write-Host " " -NoNewline
            Write-Host "$($svc.Name)" -ForegroundColor Green -NoNewline
            Write-Host (" " * (13 - $svc.Name.Length)) -NoNewline
            Write-Host "$displayName" -ForegroundColor White -NoNewline
            
            try {
                $process = Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'" | Select-Object ProcessId
                if ($process.ProcessId -gt 0) {
                    $proc = Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
                    if ($proc) {
                        Write-Host " | " -NoNewline
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

Write-Host "`nHit up @MeowTonyNoh if u got ideas for tools to add" -ForegroundColor Cyan
Write-Host "Downloads are located in: $DownloadPath" -ForegroundColor Cyan
