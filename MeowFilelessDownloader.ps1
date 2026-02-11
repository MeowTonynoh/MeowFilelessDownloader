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
    Write-Host "[!] You might be running a 3rd party AV — some files could get deleted." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# ─── Download helpers ──────────────────────────────────────────────────────────
function Download-File {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$ToolName
    )

    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  [~] Downloading $ToolName..." -NoNewline
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -UserAgent "Mozilla/5.0" -UseBasicParsing | Out-Null

        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Expand-Archive -Path $outputPath -DestinationPath $extractPath -Force | Out-Null
            Remove-Item $outputPath -Force | Out-Null
        }

        Write-Host " [DONE]" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

function Download-Tools {
    param(
        [array]$Tools,
        [string]$CategoryName
    )

    $successCount = 0

    Write-Host "`n[*] Downloading $CategoryName tools..." -ForegroundColor Cyan
    foreach ($tool in $Tools) {
        if (Download-File -Url $tool.Url -FileName $tool.File -ToolName $tool.Name) {
            $successCount++
        }
    }

    $color = if ($successCount -eq $Tools.Count) { "Green" } else { "Yellow" }
    Write-Host ("[$CategoryName] $successCount/$($Tools.Count) tools downloaded successfully") -ForegroundColor $color
}

# ─── Tool definitions ──────────────────────────────────────────────────────────

$zimmermanTools = @(
    @{ Name = "bstrings";           Url = "https://download.ericzimmermanstools.com/net9/bstrings.zip";          File = "bstrings.zip" },
    @{ Name = "TimelineExplorer";   Url = "https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip";  File = "TimelineExplorer.zip" }
)

$nirsoftTools = @(
    @{ Name = "FullEventLogView";   Url = "https://www.nirsoft.net/utils/fulleventlogview-x64.zip";              File = "fulleventlogview-x64.zip" }
)

$spokwnTools = @(
    @{ Name = "KernelLiveDumpTool"; Url = "https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File = "KernelLiveDumpTool.exe" }
)

$otherTools = @(
    @{ Name = "Everything Search";  Url = "https://www.voidtools.com/Everything-1.4.1.1032.x64-Setup.exe";       File = "Everything-1.4.1.1032.x64-Setup.exe" },
    @{ Name = "Hayabusa";           Url = "https://github.com/Yamato-Security/hayabusa/releases/download/v3.8.0/hayabusa-3.8.0-win-x64.zip"; File = "hayabusa-3.8.0-win-x64.zip" },
    @{ Name = "HxD Hex Editor";     Url = "https://mh-nexus.de/downloads/HxDSetupEN.zip";                        File = "HxDSetupEN.zip" },
    @{ Name = "BinText";            Url = "https://web.archive.org/web/2024/https://www.mcafee.com/hk/downloads/free-tools/bintext.aspx"; File = "BinText.zip" },
    @{ Name = "FTK Imager";         Url = "https://accessdata-ftk-imager.software.informer.com/3.1/";             File = "FTK_Imager_Setup.exe" }
)

# ─── Menu ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "             Meow Fileless Downloader v1.0              " -ForegroundColor Cyan
Write-Host "             Tool drop folder: $DownloadPath            " -ForegroundColor DarkCyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""

$installAllResponse = Read-Host "Download ALL tool categories? (Y/N)"
$installAll = $installAllResponse -match '^[Yy]'

if ($installAll) {
    Write-Host "`n[+] Downloading all categories..." -ForegroundColor Green

    Download-Tools -Tools $zimmermanTools  -CategoryName "Zimmerman's"
    Download-Tools -Tools $nirsoftTools   -CategoryName "Nirsoft"
    Download-Tools -Tools $spokwnTools    -CategoryName "Spokwn's"
    Download-Tools -Tools $otherTools     -CategoryName "Other"

    $runtimeResponse = Read-Host "`nInstall .NET 9 Runtime? (required for Zimmerman tools) (Y/N)"
    if ($runtimeResponse -match '^[Yy]') {
        Download-File -Url "https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-win-x64.exe" `
                      -FileName "dotnet-sdk-9.0.306-win-x64.exe" `
                      -ToolName ".NET 9 SDK"
    }

} else {
    Write-Host "`n[*] Select categories to download:" -ForegroundColor Yellow

    $response = Read-Host "`nDownload Zimmerman's tools? (bstrings, TimelineExplorer) (Y/N)"
    if ($response -match '^[Yy]') {
        Download-Tools -Tools $zimmermanTools -CategoryName "Zimmerman's"

        $runtimeResponse = Read-Host "`nInstall .NET 9 Runtime? (required for Zimmerman tools) (Y/N)"
        if ($runtimeResponse -match '^[Yy]') {
            Download-File -Url "https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-win-x64.exe" `
                          -FileName "dotnet-sdk-9.0.306-win-x64.exe" `
                          -ToolName ".NET 9 SDK"
        }
    }

    $response = Read-Host "`nDownload Nirsoft tools? (FullEventLogView) (Y/N)"
    if ($response -match '^[Yy]') {
        Download-Tools -Tools $nirsoftTools -CategoryName "Nirsoft"
    }

    $response = Read-Host "`nDownload Spokwn's tools? (KernelLiveDumpTool) (Y/N)"
    if ($response -match '^[Yy]') {
        Download-Tools -Tools $spokwnTools -CategoryName "Spokwn's"
    }

    $response = Read-Host "`nDownload other tools? (Everything, Hayabusa, HxD, BinText, FTK Imager) (Y/N)"
    if ($response -match '^[Yy]') {
        Download-Tools -Tools $otherTools -CategoryName "Other"
    }
}

# ─── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "[+] All done! Hit up @Tonynoh if you got ideas for tools to add." -ForegroundColor Magenta
Write-Host "[+] Tools are located in: $DownloadPath" -ForegroundColor Cyan
Write-Host ""
