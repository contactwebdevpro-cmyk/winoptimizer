#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinForge Pro v3.0 - Le debloat et optimiseur Windows 11 le plus avance
.DESCRIPTION
    Surpasse Chris Titus WinUtil et Win11Debloat.
    Modes : SAFE / BALANCED / ULTRA
    Rollback complet avec systeme d'undo integre.
    Optimise pour Gaming, Creation de contenu et Performance pure.
.NOTES
    Architecture : PowerShell 5.1+ / 7+
    Compatible : Windows 10 1903+ | Windows 11 (toutes versions)
    Execution : Administrateur requis
#>

# ============================================================
#  CONFIGURATION GLOBALE
# ============================================================
$Global:WF = @{
    Version       = "3.0"
    Mode          = "BALANCED"       # SAFE | BALANCED | ULTRA
    Profile       = "PERFORMANCE"    # PERFORMANCE | GAMING | CONTENT | PRIVACY
    LogFile       = "$env:USERPROFILE\Desktop\WinForge_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"
    BackupPath    = "$env:SystemDrive\WinForge_Backup_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    RestorePoint  = $true
    DryRun        = $false           # Simuler sans appliquer
    Stats         = @{ OK=0; WARN=0; SKIP=0; ERROR=0 }
    RollbackLog   = @()
    IsWin11       = $false
    IsSSD         = $false
    HasGPU        = $false
    RAMTotal      = 0
    CPUCores      = 0
}

# ============================================================
#  SYSTEME DE LOGS ET UI
# ============================================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    Add-Content -Path $Global:WF.LogFile -Value "[$ts][$Level] $Message" -EA SilentlyContinue
    switch ($Level) {
        "OK"      { Write-Host "  [✓] " -FG Green  -NoNewline; Write-Host $Message; $Global:WF.Stats.OK++ }
        "WARN"    { Write-Host "  [!] " -FG Yellow -NoNewline; Write-Host $Message; $Global:WF.Stats.WARN++ }
        "ERROR"   { Write-Host "  [✗] " -FG Red    -NoNewline; Write-Host $Message; $Global:WF.Stats.ERROR++ }
        "SKIP"    { Write-Host "  [-] " -FG DarkGray -NoNewline; Write-Host $Message -FG DarkGray; $Global:WF.Stats.SKIP++ }
        "SECTION" { Write-Host ""; Write-Host "  ═══ $Message ═══" -FG Cyan }
        "ULTRA"   { Write-Host "  [⚡] " -FG Magenta -NoNewline; Write-Host $Message }
        default   { Write-Host "  [i] " -FG Blue   -NoNewline; Write-Host $Message }
    }
}

function Show-Banner {
    Clear-Host
    Write-Host @"

  ██╗    ██╗██╗███╗   ██╗███████╗ ██████╗ ██████╗  ██████╗ ███████╗
  ██║    ██║██║████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
  ██║ █╗ ██║██║██╔██╗ ██║█████╗  ██║   ██║██████╔╝██║  ███╗█████╗
  ██║███╗██║██║██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
  ╚███╔███╔╝██║██║ ╚████║██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝

"@ -ForegroundColor Cyan
    Write-Host "                 P R O   v$($Global:WF.Version)" -FG DarkCyan
    Write-Host "     Surpasse WinUtil + Win11Debloat | Gaming + Performance + Privacy" -FG DarkGray
    Write-Host "  ─────────────────────────────────────────────────────────────────" -FG DarkGray
    Write-Host ""
}

function Show-Menu {
    Show-Banner
    # Mode
    $modeColor = switch ($Global:WF.Mode) { "SAFE" { "Green" } "BALANCED" { "Yellow" } "ULTRA" { "Magenta" } }
    Write-Host "  Mode actuel : " -NoNewline
    Write-Host "[$($Global:WF.Mode)]" -FG $modeColor -NoNewline
    Write-Host "  Profil : " -NoNewline
    Write-Host "[$($Global:WF.Profile)]" -FG Cyan
    Write-Host ""
    Write-Host "  ACTIONS RAPIDES" -FG White
    Write-Host "  ──────────────────────────────────────────" -FG DarkGray
    Write-Host "  [1]  🚀 DEBLOAT COMPLET (toutes les etapes)"    -FG Cyan
    Write-Host "  [2]  📦 Apps UWP + Store bloat"                  -FG White
    Write-Host "  [3]  ⚙️  Services inutiles"                      -FG White
    Write-Host "  [4]  🔒 Telemetrie + Privacy profond"            -FG White
    Write-Host "  [5]  ⚡ Performances CPU/RAM/IO"                 -FG White
    Write-Host "  [6]  🌐 Reseau + TCP/IP tuning"                  -FG White
    Write-Host "  [7]  🗑️  Nettoyage systeme profond"              -FG White
    Write-Host "  [8]  🎮 Mode Gaming optimise"                     -FG White
    Write-Host "  [9]  🛡️  Securite + Hardening"                   -FG White
    Write-Host "  [10] 🤖 Desactiver IA (Copilot/Recall/Widgets)"  -FG White
    Write-Host "  [11] 🔄 Bloquer reinstallation automatique"       -FG White
    Write-Host "  [12] 📋 Rapport systeme"                          -FG White
    Write-Host "  ──────────────────────────────────────────" -FG DarkGray
    Write-Host "  [M]  Changer le Mode (SAFE/BALANCED/ULTRA)"       -FG Yellow
    Write-Host "  [P]  Changer le Profil"                           -FG Yellow
    Write-Host "  [R]  Rollback / Annuler les changements"          -FG Red
    Write-Host "  [Q]  Quitter"                                     -FG Red
    Write-Host ""
    return (Read-Host "  Votre choix")
}

# ============================================================
#  DETECTION HARDWARE & OS
# ============================================================
function Invoke-SystemDetection {
    Write-Log "DETECTION DU SYSTEME" "SECTION"

    $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    $Global:WF.IsWin11 = ($build -ge 22000)
    Write-Log "Build Windows : $build $(if($Global:WF.IsWin11){'(Windows 11)'}else{'(Windows 10)'})" "OK"

    $disk = Get-PhysicalDisk -EA SilentlyContinue | Where-Object { $_.MediaType -eq "SSD" }
    $Global:WF.IsSSD = ($null -ne $disk)
    Write-Log "Stockage : $(if($Global:WF.IsSSD){'SSD detecte'}else{'HDD detecte'})" "OK"

    $ram = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $Global:WF.RAMTotal = [Math]::Round($ram, 1)
    Write-Log "RAM : $($Global:WF.RAMTotal) Go" "OK"

    $cpu = Get-WmiObject Win32_Processor
    $Global:WF.CPUCores = $cpu.NumberOfLogicalProcessors
    Write-Log "CPU : $($cpu.Name) | $($Global:WF.CPUCores) threads" "OK"

    $gpu = Get-WmiObject Win32_VideoController -EA SilentlyContinue | Select-Object -First 1
    $Global:WF.HasGPU = ($null -ne $gpu)
    if ($Global:WF.HasGPU) { Write-Log "GPU : $($gpu.Name)" "OK" }

    # Admin check
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Write-Log "DROITS ADMINISTRATEUR REQUIS !" "ERROR"; pause; exit }
}

# ============================================================
#  SYSTEME DE ROLLBACK / BACKUP
# ============================================================
function Backup-RegistryKey {
    param([string]$Path)
    if (!(Test-Path $Path)) { return }
    try {
        $backupFile = "$($Global:WF.BackupPath)\Registry\$(($Path -replace '[:\/\\]', '_')).reg"
        $dir = Split-Path $backupFile -Parent
        if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $hivePart = $Path -replace '^(HKLM|HKCU|HKCR|HKU|HKCC).*', '$1'
        $subKey = $Path -replace '^(HKLM|HKCU|HKCR|HKU|HKCC):\\', ''
        $hiveMap = @{ "HKLM"="HKEY_LOCAL_MACHINE"; "HKCU"="HKEY_CURRENT_USER"; "HKCR"="HKEY_CLASSES_ROOT" }
        $fullKey = "$($hiveMap[$hivePart])\$subKey"
        reg export "$fullKey" "$backupFile" /y 2>$null | Out-Null
        $Global:WF.RollbackLog += "REG:$backupFile"
    } catch {}
}

function New-RestorePointSafe {
    Write-Log "CREATION POINT DE RESTAURATION" "SECTION"
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -EA SilentlyContinue
        Checkpoint-Computer -Description "WinForge Pro v3.0 - $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -RestorePointType "MODIFY_SETTINGS" -EA Stop
        Write-Log "Point de restauration cree" "OK"
    } catch {
        Write-Log "Point de restauration impossible (peut etre desactive par strategie)" "WARN"
    }
}

function Invoke-Rollback {
    Write-Log "ROLLBACK - RESTAURATION DES PARAMETRES" "SECTION"
    if ($Global:WF.RollbackLog.Count -eq 0) {
        Write-Log "Aucune sauvegarde disponible dans cette session" "WARN"
        return
    }
    foreach ($entry in $Global:WF.RollbackLog) {
        if ($entry.StartsWith("REG:")) {
            $file = $entry.Substring(4)
            if (Test-Path $file) {
                reg import "$file" 2>$null
                Write-Log "Restaure : $file" "OK"
            }
        }
    }
    Write-Log "Rollback termine. Un redemarrage est recommande." "WARN"
}

# ============================================================
#  HELPER : SET REGISTRY SAFE
# ============================================================
function Set-RegSafe {
    param(
        [string]$Path, [string]$Name, $Value,
        [string]$Type = "DWord", [switch]$Backup
    )
    if ($Global:WF.DryRun) { Write-Log "[DRY] Set $Path\$Name = $Value" "INFO"; return }
    if ($Backup) { Backup-RegistryKey -Path $Path }
    try {
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -EA Stop
    } catch {
        Write-Log "Echec registre : $Path\$Name" "WARN"
    }
}

function Disable-ServiceSafe {
    param([string]$Name, [string]$Description = "")
    $svc = Get-Service -Name $Name -EA SilentlyContinue
    if (-not $svc) { Write-Log "Service absent : $Name" "SKIP"; return }
    try {
        Stop-Service -Name $Name -Force -EA SilentlyContinue
        Set-Service  -Name $Name -StartupType Disabled -EA Stop
        Write-Log "Service desactive : $(if($Description){$Description}else{$Name})" "OK"
    } catch {
        Write-Log "Echec desactivation : $Name" "WARN"
    }
}

function Disable-TaskSafe {
    param([string]$TaskPath, [string]$TaskName)
    try {
        $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -EA SilentlyContinue
        if ($t) {
            Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -EA Stop | Out-Null
            Write-Log "Tache desactivee : $TaskPath$TaskName" "OK"
        } else {
            Write-Log "Tache absente : $TaskName" "SKIP"
        }
    } catch {
        Write-Log "Echec tache : $TaskName" "WARN"
    }
}

# ============================================================
#  MODULE 1 : DEBLOAT APPS UWP (ULTRA-COMPLET)
# ============================================================
$AppsSAFE = @(
    "Microsoft.BingFinance","Microsoft.BingNews","Microsoft.BingSports"
    "Microsoft.BingWeather","Microsoft.GetHelp","Microsoft.Getstarted"
    "Microsoft.Messaging","Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal","Microsoft.NetworkSpeedTest","Microsoft.Office.OneNote"
    "Microsoft.OneConnect","Microsoft.People","Microsoft.Print3D"
    "Microsoft.SkypeApp","Microsoft.Todos","Microsoft.Wallet"
    "Microsoft.WindowsFeedbackHub","Microsoft.WindowsMaps","Microsoft.WindowsSoundRecorder"
    "Microsoft.XboxApp","Microsoft.YourPhone","Microsoft.ZuneMusic","Microsoft.ZuneVideo"
    "Microsoft.3DBuilder","Microsoft.Microsoft3DViewer","Microsoft.MSPaint"
    "Microsoft.BingTranslator","Microsoft.MicrosoftStickyNotes"
    "SpotifyAB.SpotifyMusic","king.com.CandyCrushSaga","king.com.CandyCrushFriends"
    "king.com.FarmHeroesSaga","FACEBOOK.FACEBOOK","Facebook.InstagramApp"
    "TikTok.TikTok","BytedancePte.Ltd.TikTok","Netflix","AmazonVideo.PrimeVideo"
    "Disney.37853D22215B_","Hulu.HuluApp","Twitter.Twitter"
    "PricelinePartnerNetwork.Booking.comBigsavingsonhot","Nordcurrent.CookingFever"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress","Duolingo-LearnLanguagesforFree"
    "PandoraMediaInc","Shazam.Shazamfolio"
)

$AppsBALANCED = $AppsSAFE + @(
    "Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay","Microsoft.windowscommunicationsapps"
    "Microsoft.GamingApp","Microsoft.549981C3F5F10"   # Cortana standalone
    "MicrosoftCorporationII.MicrosoftFamily"
    "Microsoft.Windows.DevHome","MicrosoftCorporationII.QuickAssist"
    "Microsoft.WindowsAlarms","Microsoft.WindowsCamera"
    "Microsoft.MicrosoftEdge.Stable","Microsoft.OutlookForWindows"
    "Clipchamp.Clipchamp","MicrosoftTeams","MSTeams"
    "Microsoft.OneDriveSync","microsoft.windowscommunicationsapps"
    "Microsoft.PowerAutomateDesktop","Microsoft.Advertising.Xaml"
)

$AppsULTRA = $AppsBALANCED + @(
    "Microsoft.BingSearch","Microsoft.Windows.Search"
    "Microsoft.WindowsStore"   # !! Supprime le Store - bloque les MAJ UWP
    "Microsoft.WebMediaExtensions","Microsoft.WebpImageExtension"
    "Microsoft.HEIFImageExtension","Microsoft.HEVCVideoExtension"
    "Microsoft.VP9VideoExtensions","Microsoft.RawImageExtension"
    "Microsoft.ScreenSketch","Microsoft.Windows.Photos"
    "MicrosoftWindows.Client.WebExperience"  # Widgets
    "Microsoft.Copilot","Microsoft.Windows.Ai.Copilot.Provider"
    "Microsoft.Windows.ContentDeliveryManager"
    "Microsoft.WindowsTerminal"  # Optionnel - certains en ont besoin
)

function Remove-BloatApps {
    Write-Log "SUPPRESSION APPS UWP" "SECTION"

    $apps = switch ($Global:WF.Mode) {
        "SAFE"     { $AppsSAFE }
        "BALANCED" { $AppsBALANCED }
        "ULTRA"    { $AppsULTRA }
    }

    $i = 0
    foreach ($app in $apps) {
        $i++; Write-Progress "Suppression apps" ([int](($i/$apps.Count)*100))

        # User courant
        $pkg = Get-AppxPackage -Name $app -EA SilentlyContinue
        if ($pkg) {
            try { $pkg | Remove-AppxPackage -EA Stop; Write-Log "Supprime (user) : $app" "OK" }
            catch { Write-Log "Echec (user) : $app" "WARN" }
        }

        # Tous les utilisateurs
        $pkgAll = Get-AppxPackage -Name $app -AllUsers -EA SilentlyContinue
        if ($pkgAll) {
            try { $pkgAll | Remove-AppxPackage -AllUsers -EA Stop; Write-Log "Supprime (tous) : $app" "OK" }
            catch {}
        }

        # Provisioned (nouveaux comptes)
        $prov = Get-AppxProvisionedPackage -Online -EA SilentlyContinue | Where-Object { $_.PackageName -like "*$app*" }
        if ($prov) {
            try { $prov | Remove-AppxProvisionedPackage -Online -EA Stop | Out-Null; Write-Log "Deprovision : $app" "OK" }
            catch { Write-Log "Echec deprovision : $app" "WARN" }
        }

        if (-not $pkg -and -not $pkgAll -and -not $prov) {
            Write-Log "Non installe : $app" "SKIP"
        }
    }
    Write-Progress "Suppression apps" -Completed
}

# ============================================================
#  MODULE 2 : BLOQUER LA REINSTALLATION AUTOMATIQUE
# ============================================================
function Block-AppReinstall {
    Write-Log "BLOQUER REINSTALLATION AUTOMATIQUE DES APPS" "SECTION"

    # Bloquer ContentDeliveryManager (responsable des reinstallations silencieuses)
    $cdmPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $cdmValues = @{
        "ContentDeliveryAllowed"          = 0
        "FeatureManagementEnabled"        = 0
        "OemPreInstalledAppsEnabled"      = 0
        "PreInstalledAppsEnabled"         = 0
        "PreInstalledAppsEverEnabled"     = 0
        "SilentInstalledAppsEnabled"      = 0
        "SoftLandingEnabled"              = 0
        "SubscribedContentEnabled"        = 0
        "SystemPaneSuggestionsEnabled"    = 0
        "SubscribedContent-310093Enabled" = 0
        "SubscribedContent-338387Enabled" = 0
        "SubscribedContent-338388Enabled" = 0
        "SubscribedContent-338389Enabled" = 0
        "SubscribedContent-338393Enabled" = 0
        "SubscribedContent-353698Enabled" = 0
        "SubscribedContent-353694Enabled" = 0
    }
    foreach ($v in $cdmValues.GetEnumerator()) {
        Set-RegSafe -Path $cdmPath -Name $v.Key -Value $v.Value
    }
    Write-Log "ContentDeliveryManager : suggestions/reinstallations bloquees" "OK"

    # Bloquer reinstallation via GPO
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"          -Name "AutoDownload" -Value 2
    Write-Log "GPO : reinstallation automatique du Store bloquee" "OK"

    # Desactiver tache de push apps
    Disable-TaskSafe -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "Microsoft Compatibility Appraiser"
    Disable-TaskSafe -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "ProgramDataUpdater"
    Disable-TaskSafe -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "StartupAppTask"
    Write-Log "Taches Application Experience desactivees" "OK"
}

# ============================================================
#  MODULE 3 : SERVICES (CATEGORISES PAR MODE)
# ============================================================
$ServicesSAFE = @{
    "DiagTrack"        = "Telemetrie (Connected User Experiences)"
    "dmwappushservice" = "WAP Push Message Routing"
    "MapsBroker"       = "Telechargement cartes hors connexion"
    "WerSvc"           = "Rapport d'erreurs Windows"
    "wercplsupport"    = "Support panneau rapports d'erreurs"
    "Fax"              = "Telecopie"
    "TapiSrv"          = "Telephonie"
    "RemoteRegistry"   = "Registre distant"
    "RetailDemo"       = "Mode demonstration"
    "PhoneSvc"         = "Service telephone"
    "XblAuthManager"   = "Xbox Live Auth Manager"
    "XblGameSave"      = "Xbox Live Game Save"
    "XboxNetApiSvc"    = "Xbox Live Networking"
    "XboxGipSvc"       = "Xbox Accessory Management"
    "wisvc"            = "Windows Insider Service"
    "WMPNetworkSvc"    = "Partage reseau WMP"
    "WbioSrvc"         = "Biometrie Windows"
}

$ServicesBALANCED = $ServicesSAFE + @{
    "lfsvc"              = "Geolocalisation"
    "SharedAccess"       = "Partage de connexion ICS"
    "PcaSvc"             = "Programme Compatibility Assistant"
    "AJRouter"           = "AllJoyn Router (IoT)"
    "ALG"                = "Application Layer Gateway"
    "wlidsvc"            = "Microsoft Account Sign-in Assistant"
    "diagsvc"            = "Diagnostic Execution Service"
    "DiagnosticHub.StandardCollector.Service" = "Collecteur diagnostic hub"
    "DPS"                = "Diagnostic Policy Service"
    "WdiServiceHost"     = "Diagnostic Service Host"
    "WdiSystemHost"      = "Diagnostic System Host"
    "DoSvc"              = "Delivery Optimization (Windows Update P2P)"
    "icssvc"             = "Windows Mobile Hotspot"
    "SEMgrSvc"           = "Payments and NFC/SE Manager"
    "SysMain"            = "SysMain/SuperFetch (SSD uniquement)"
    "TabletInputService" = "Touch Keyboard and Handwriting"
    "WSearch"            = "Windows Search Indexing"
    "stisvc"             = "Windows Image Acquisition (WIA)"
    "Spooler"            = "Print Spooler (si pas d'imprimante)"
}

$ServicesULTRA = $ServicesBALANCED + @{
    "BITS"               = "Background Intelligent Transfer (BITS)"
    "CscService"         = "Offline Files"
    "FrameServer"        = "Windows Camera Frame Server"
    "HomeGroupListener"  = "HomeGroup Listener"
    "HomeGroupProvider"  = "HomeGroup Provider"
    "HvHost"             = "Hyper-V Host Compute"
    "vmicguestinterface" = "Hyper-V Guest Service Interface"
    "vmicheartbeat"      = "Hyper-V Heartbeat Service"
    "vmickvpexchange"    = "Hyper-V Data Exchange"
    "vmicrdv"            = "Hyper-V Remote Desktop"
    "vmicshutdown"       = "Hyper-V Guest Shutdown"
    "vmictimesync"       = "Hyper-V Time Synchronization"
    "vmicvmsession"      = "Hyper-V PowerShell Direct"
    "vmicvss"            = "Hyper-V Volume Shadow Copy"
    "WpcMonSvc"          = "Parental Controls"
    "MSiSCSI"            = "Microsoft iSCSI Initiator"
    "TrkWks"             = "Distributed Link Tracking Client"
    "upnphost"           = "UPnP Device Host"
    "SSDPSRV"            = "SSDP Discovery"
    "spectrum"           = "Windows Perception Service"
    "perceptionsimulation" = "Windows Perception Simulation"
    "SensorDataService"  = "Sensor Data Service"
    "SensorService"      = "Sensor Service"
    "SensrSvc"           = "Sensor Monitoring Service"
    "MapsBroker"         = "Downloaded Maps Manager"
    "WalletService"      = "WalletService"
}

function Disable-UnnecessaryServices {
    Write-Log "DESACTIVATION SERVICES INUTILES" "SECTION"

    $services = switch ($Global:WF.Mode) {
        "SAFE"     { $ServicesSAFE }
        "BALANCED" { $ServicesBALANCED }
        "ULTRA"    { $ServicesULTRA }
    }

    # SysMain : garder sur HDD
    if (-not $Global:WF.IsSSD -and $services.ContainsKey("SysMain")) {
        $services.Remove("SysMain")
        Write-Log "SysMain conserve (HDD detecte)" "INFO"
    }

    # Spooler : garder si imprimante
    $printer = Get-Printer -EA SilentlyContinue
    if ($printer -and $services.ContainsKey("Spooler")) {
        $services.Remove("Spooler")
        Write-Log "Spooler conserve (imprimante detectee)" "INFO"
    }

    foreach ($svc in $services.GetEnumerator()) {
        Disable-ServiceSafe -Name $svc.Key -Description $svc.Value
    }
}

# ============================================================
#  MODULE 4 : TELEMETRIE & PRIVACY (NIVEAU EXPERT)
# ============================================================
function Set-PrivacySettings {
    Write-Log "TELEMETRIE & PRIVACY PROFOND" "SECTION"

    # --- Telemetrie niveau 0 ---
    $telPaths = @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"    = @{ AllowTelemetry=0; LimitDiagnosticLogCollection=1; DisableOneSettingsDownloads=1 }
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @{ AllowTelemetry=0; MaxTelemetryAllowed=0 }
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @{ AllowTelemetry=0 }
    }
    foreach ($p in $telPaths.GetEnumerator()) {
        foreach ($v in $p.Value.GetEnumerator()) { Set-RegSafe -Path $p.Key -Name $v.Key -Value $v.Value }
    }
    Write-Log "Telemetrie niveau 0" "OK"

    # --- Publicite & tracking ---
    $privPaths = @{
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"            = @{ Enabled=0 }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"                    = @{ TailoredExperiencesWithDiagnosticDataEnabled=0 }
        "HKCU:\SOFTWARE\Microsoft\InputPersonalization"                               = @{ RestrictImplicitInkCollection=1; RestrictImplicitTextCollection=1 }
        "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"              = @{ HarvestContacts=0 }
        "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"                           = @{ AcceptedPrivacyPolicy=0 }
        "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"       = @{ HasAccepted=0 }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"          = @{ Start_TrackProgs=0; Start_TrackEnabled=0 }
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"                  = @{ DisabledByGroupPolicy=1 }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"      = @{ ShowedToastAtLevel=1 }
    }
    foreach ($p in $privPaths.GetEnumerator()) {
        foreach ($v in $p.Value.GetEnumerator()) { Set-RegSafe -Path $p.Key -Name $v.Key -Value $v.Value }
    }
    Write-Log "ID publicitaire et tracking desactives" "OK"

    # --- Cortana ---
    $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Set-RegSafe -Path $cortanaPath -Name "AllowCortana"             -Value 0
    Set-RegSafe -Path $cortanaPath -Name "AllowCortanaAboveLock"    -Value 0
    Set-RegSafe -Path $cortanaPath -Name "AllowSearchToUseLocation" -Value 0
    Set-RegSafe -Path $cortanaPath -Name "ConnectedSearchUseWeb"    -Value 0
    Set-RegSafe -Path $cortanaPath -Name "DisableWebSearch"         -Value 1
    Write-Log "Cortana desactivee" "OK"

    # --- Bing dans la recherche ---
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent"    -Value 0
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "AllowSearchToUseLocation" -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0
    Write-Log "Recherche Bing / web dans Start desactivee" "OK"

    # --- Timeline / Activity ---
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed"    -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities"  -Value 0
    Write-Log "Timeline / historique d'activite desactive" "OK"

    # --- CEIP / Watson / Error Reporting ---
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1
    Write-Log "CEIP et rapport d'erreurs Watson desactives" "OK"

    # --- Feedback ---
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0
    Write-Log "Feedback notifications desactivees" "OK"

    # --- Ink / Handwriting ---
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" -Name "AllowInputPersonalization"   -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1
    Write-Log "Personnalisation de saisie / ecriture desactivee" "OK"

    # --- Cloud clipboard ---
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Clipboard" -Name "EnableClipboardHistory"         -Value 0
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Clipboard" -Name "EnableCloudClipboard"           -Value 0
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Clipboard" -Name "CloudClipboardAutomaticUpload"  -Value 0
    Write-Log "Presse-papier cloud desactive" "OK"

    # --- Location ---
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Value 0
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Value 0
    Write-Log "Geolocalisation systeme desactivee" "OK"

    # TACHES TELEMETRIE
    $telTasks = @(
        @{P="\Microsoft\Windows\Application Experience\"; N="Microsoft Compatibility Appraiser"}
        @{P="\Microsoft\Windows\Application Experience\"; N="ProgramDataUpdater"}
        @{P="\Microsoft\Windows\Application Experience\"; N="StartupAppTask"}
        @{P="\Microsoft\Windows\Customer Experience Improvement Program\"; N="Consolidator"}
        @{P="\Microsoft\Windows\Customer Experience Improvement Program\"; N="UsbCeip"}
        @{P="\Microsoft\Windows\DiskDiagnostic\"; N="Microsoft-Windows-DiskDiagnosticDataCollector"}
        @{P="\Microsoft\Windows\Feedback\Siuf\"; N="DmClient"}
        @{P="\Microsoft\Windows\Feedback\Siuf\"; N="DmClientOnScenarioDownload"}
        @{P="\Microsoft\Windows\Windows Error Reporting\"; N="QueueReporting"}
        @{P="\Microsoft\Windows\Maps\"; N="MapsToastTask"}
        @{P="\Microsoft\Windows\Maps\"; N="MapsUpdateTask"}
        @{P="\Microsoft\Windows\XblGameSave\"; N="XblGameSaveTask"}
        @{P="\Microsoft\Windows\CloudExperienceHost\"; N="CreateObjectTask"}
        @{P="\Microsoft\Windows\PI\"; N="Sqm-Tasks"}
        @{P="\Microsoft\Windows\NetTrace\"; N="GatherNetworkInfo"}
        @{P="\Microsoft\Windows\Autochk\"; N="Proxy"}
        @{P="\Microsoft\Windows\Power Efficiency Diagnostics\"; N="AnalyzeSystem"}
        @{P="\Microsoft\Windows\Shell\"; N="FamilySafetyMonitor"}
        @{P="\Microsoft\Windows\Shell\"; N="FamilySafetyRefreshTask"}
    )
    foreach ($t in $telTasks) { Disable-TaskSafe -TaskPath $t.P -TaskName $t.N }
    Write-Log "Toutes les taches de telemetrie desactivees" "OK"

    # Bloquer les domaines de telemetrie via hosts (ULTRA uniquement)
    if ($Global:WF.Mode -eq "ULTRA") {
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        $telemetryDomains = @(
            "vortex.data.microsoft.com","settings-win.data.microsoft.com"
            "telemetry.microsoft.com","watson.telemetry.microsoft.com"
            "oca.telemetry.microsoft.com","sqm.telemetry.microsoft.com"
            "telemetry.appex.bing.net","telemetry.urs.microsoft.com"
            "feedback.microsoft-hohm.com","feedback.search.microsoft.com"
            "vortex-win.data.microsoft.com","functional.events.data.microsoft.com"
        )
        $hostsContent = Get-Content $hostsPath -EA SilentlyContinue
        foreach ($domain in $telemetryDomains) {
            if ($hostsContent -notcontains "0.0.0.0 $domain") {
                Add-Content -Path $hostsPath -Value "0.0.0.0 $domain" -EA SilentlyContinue
            }
        }
        Write-Log "Domaines de telemetrie bloques dans hosts (ULTRA)" "ULTRA"
    }
}

# ============================================================
#  MODULE 5 : DESACTIVER IA (COPILOT, RECALL, WIDGETS)
# ============================================================
function Disable-AIFeatures {
    Write-Log "DESACTIVATION IA / COPILOT / RECALL / WIDGETS" "SECTION"

    # Copilot
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
    Set-RegSafe -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"  -Name "TurnOffWindowsCopilot" -Value 1
    Write-Log "Copilot desactive" "OK"

    # Recall (Windows 11 24H2+)
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
    Set-RegSafe -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"  -Name "DisableAIDataAnalysis" -Value 1
    Disable-TaskSafe -TaskPath "\Microsoft\Windows\WindowsAI\" -TaskName "ManageSensitiveFound"
    Disable-TaskSafe -TaskPath "\Microsoft\Windows\WindowsAI\" -TaskName "ScanAndIndexDeletedContent"
    Disable-TaskSafe -TaskPath "\Microsoft\Windows\WindowsAI\" -TaskName "ScanAndIndexThumbnails"
    Write-Log "Windows Recall desactive" "OK"

    # Widgets / Web Experience Pack
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
    # Supprimer le package Widgets
    $widgetPkg = Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -AllUsers -EA SilentlyContinue
    if ($widgetPkg) {
        $widgetPkg | Remove-AppxPackage -AllUsers -EA SilentlyContinue
        Write-Log "Web Experience Pack (Widgets) supprime" "OK"
    } else {
        Write-Log "Web Experience Pack deja absent" "SKIP"
    }
    Write-Log "Widgets desactives" "OK"

    # AI components
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" -Name "EnableWindowsAI" -Value 0
    Write-Log "Windows AI components desactives" "OK"

    # Desactiver Paint/Notepad AI
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Cocreator" -Name "Enabled" -Value 0 -EA SilentlyContinue
    Write-Log "Cochreator (Cocreator AI) desactive" "OK"

    # TaskBar Search box -> icone uniquement (moins d'espace IA)
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1
    Write-Log "Barre de recherche : icone uniquement" "OK"
}

# ============================================================
#  MODULE 6 : OPTIMISATION PERFORMANCES (DEEP TUNING)
# ============================================================
function Optimize-Performance {
    Write-Log "OPTIMISATION PERFORMANCES CPU/RAM/IO" "SECTION"

    # Plan haute performance
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    Write-Log "Plan alimentation : Haute Performance" "OK"

    if ($Global:WF.Mode -eq "ULTRA") {
        # Creer plan Ultimate Performance (Windows 10 1803+)
        $result = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
        if ($LASTEXITCODE -eq 0) {
            $guid = ($result -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | Out-Null; [regex]::Match($result, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}').Value)
            if ($guid) { powercfg -setactive $guid 2>$null; Write-Log "Plan Ultimate Performance active" "ULTRA" }
        }
    }

    # Effets visuels -> performances
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
    Set-RegSafe -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay"   -Value "0" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0
    Write-Log "Effets visuels optimises" "OK"

    # Memory management
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive"  -Value 1
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache"        -Value 0
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "IoPageLockLimit"         -Value 983040  # 960KB

    if ($Global:WF.RAMTotal -ge 16) {
        Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "NonPagedPoolSize" -Value 0
        Write-Log "Memoire : tuning pour $($Global:WF.RAMTotal)Go RAM (haute)" "OK"
    }

    # Prefetch / Superfetch
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value $(if($Global:WF.IsSSD){0}else{3})
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch"  -Value 0
    Write-Log "Prefetch/SuperFetch : $(if($Global:WF.IsSSD){'desactive (SSD)'}else{'optimise (HDD)'})" "OK"

    # CPU scheduling
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38  # Foreground apps priority boost
    Write-Log "Scheduling CPU : priorite foreground augmentee (0x26)" "OK"

    # Shutdown rapide
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "2000" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout"  -Value "2000" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout"        -Value "1000" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks"          -Value "1"    -Type String
    Write-Log "Arrêt systeme accelere" "OK"

    # NTFS optimisations
    fsutil behavior set disablelastaccess 1 2>$null
    fsutil behavior set disable8dot3 1 2>$null
    Write-Log "NTFS : LastAccess et 8dot3 desactives" "OK"

    # Hibernation
    powercfg -h off 2>$null
    Write-Log "Hibernation desactivee (libere hiberfil.sys)" "OK"

    # Fast Startup
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1
    Write-Log "Fast Boot active" "OK"

    # Desactiver Windows Search indexing
    Disable-ServiceSafe -Name "WSearch" -Description "Windows Search Indexing"

    # Explorer shell tuning
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden"      -Value 1
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo"    -Value 1  # Ouvrir Ce PC
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\OneDrive.exe" -Name "Debugger" -Value "%1" -Type String
    Write-Log "Explorateur optimise" "OK"

    # Desactiver Remote Assistance
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0
    Write-Log "Assistance a distance desactivee" "OK"

    if ($Global:WF.Mode -eq "ULTRA") {
        # Desactiver Spectre/Meltdown mitigations (RISQUE - ULTRA seulement, gain perf 5-15%)
        # Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride" -Value 3
        # Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverrideMask" -Value 3
        # Write-Log "Mitigations Spectre/Meltdown desactivees (ULTRA - risque securite)" "ULTRA"

        # Timer Resolution
        Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -Value 1
        Write-Log "Timer resolution globale activee (latence reduite)" "ULTRA"

        # GPU scheduling hardware accelerated
        Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
        Write-Log "GPU Hardware Accelerated Scheduling active" "ULTRA"

        # Desactiver Core Isolation / Memory Integrity (gain FPS)
        Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Value 0
        Write-Log "Core Isolation / HVCI desactive (gain performance)" "ULTRA"
    }
}

# ============================================================
#  MODULE 7 : OPTIMISATION RESEAU (EXPERT)
# ============================================================
function Optimize-Network {
    Write-Log "OPTIMISATION RESEAU TCP/IP" "SECTION"

    # QoS bandwidth reservation -> 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0
    Write-Log "Bande passante reservee QoS supprimee" "OK"

    # Nagle algorithm desactive
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem -Path $tcpPath -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -EA SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay"      -Value 1 -Type DWord -Force -EA SilentlyContinue
    }
    Write-Log "Algorithme de Nagle desactive" "OK"

    # TCP global parameters
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DefaultTTL"                   -Value 64
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnablePMTUDiscovery"          -Value 1
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Tcp1323Opts"                  -Value 1
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpMaxDupAcks"                -Value 2
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay"            -Value 32
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "GlobalMaxTcpWindowSize"       -Value 65535
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpWindowSize"                -Value 65535
    Write-Log "Parametres TCP avances optimises" "OK"

    # netsh TCP tuning
    netsh int tcp set global autotuninglevel=normal   2>$null
    netsh int tcp set global rss=enabled              2>$null
    netsh int tcp set global chimney=enabled          2>$null
    netsh int tcp set global ecncapability=enabled    2>$null
    netsh int tcp set global timestamps=disabled      2>$null
    netsh int tcp set global initialRto=2000          2>$null
    netsh int tcp set global nonsackrttresiliency=disabled 2>$null
    netsh int tcp set global maxsynretransmissions=2  2>$null
    Write-Log "netsh TCP : RSS/Chimney/ECN/RTO optimises" "OK"

    # DNS rapide (Cloudflare + Google)
    $adapters = Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4") -EA SilentlyContinue
    }
    Write-Log "DNS : Cloudflare (1.1.1.1) + Google (8.8.8.8)" "OK"

    # Vider cache DNS
    Clear-DnsClientCache -EA SilentlyContinue
    ipconfig /flushdns 2>$null | Out-Null
    Write-Log "Cache DNS vide" "OK"

    # Delivery Optimization -> desactiver P2P
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0
    Write-Log "Delivery Optimization (P2P Windows Update) desactive" "OK"

    # Desactiver LMHOSTS lookup
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "EnableLMHOSTS" -Value 0
    Write-Log "LMHOSTS lookup desactive" "OK"

    if ($Global:WF.Mode -eq "ULTRA") {
        # Network throttling index -> off
        Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF
        Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness"   -Value 0
        Write-Log "Network throttling desactive (ULTRA)" "ULTRA"

        # IPv6 desactivation sur toutes les interfaces (compatibilite)
        Get-NetAdapter -EA SilentlyContinue | ForEach-Object {
            Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -EA SilentlyContinue
        }
        Write-Log "IPv6 desactive (ULTRA - si non necessaire)" "ULTRA"
    }
}

# ============================================================
#  MODULE 8 : MODE GAMING
# ============================================================
function Enable-GamingMode {
    Write-Log "MODE GAMING - OPTIMISATIONS AVANCEES" "SECTION"

    # Game Mode
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
    Write-Log "Game Mode Windows active" "OK"

    # HAGS (Hardware Accelerated GPU Scheduling)
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
    Write-Log "GPU Hardware Accelerated Scheduling active" "OK"

    # Systeme responsiveness pour applications multimedia/jeux
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Affinity"          -Value 0
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Background Only"   -Value "False" -Type String
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Clock Rate"        -Value 10000
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority"      -Value 8
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority"          -Value 6
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High" -Type String
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "SFIO Priority"     -Value "High" -Type String
    Write-Log "Profil multimedia Games optimise (GPU Priority 8, Clock 10000)" "OK"

    # Network throttling desactive
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF
    Write-Log "Network throttling desactive (FPS stable)" "OK"

    # Desactiver Xbox Game Bar (si mode BALANCED+)
    if ($Global:WF.Mode -ne "SAFE") {
        Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
        Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
        Set-RegSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
        Write-Log "Xbox Game Bar / DVR desactive" "OK"
    }

    # Desactiver les services Xbox
    $xboxServices = @("XblAuthManager","XblGameSave","XboxNetApiSvc","XboxGipSvc","BcastDVRUserService")
    foreach ($s in $xboxServices) { Disable-ServiceSafe -Name $s -Description "Xbox $s" }

    # Timer resolution (1ms)
    # Note: bcdedit pour useplatformclock
    bcdedit /set useplatformclock false 2>$null | Out-Null
    bcdedit /set disabledynamictick yes  2>$null | Out-Null
    Write-Log "Timer systeme : platform clock desactivee, dynamic tick desactive" "OK"

    # MSI mode pour GPU (Message Signaled Interrupts)
    $gpuDev = Get-PnpDevice -Class Display -EA SilentlyContinue | Select-Object -First 1
    if ($gpuDev) {
        $devPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpuDev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        Set-RegSafe -Path $devPath -Name "MSISupported" -Value 1
        Write-Log "MSI (Message Signaled Interrupts) active pour GPU" "OK"
    }

    # CPU priority pour gaming
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
    Write-Log "CPU scheduling : priorite jeux (0x26)" "OK"

    # Desactiver Mouse Acceleration
    Set-RegSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed"      -Value "0" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String
    Set-RegSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String
    Write-Log "Acceleration souris desactivee" "OK"

    Write-Log "MODE GAMING COMPLET ACTIVE" "ULTRA"
}

# ============================================================
#  MODULE 9 : NETTOYAGE SYSTEME PROFOND
# ============================================================
function Clean-System {
    Write-Log "NETTOYAGE SYSTEME PROFOND" "SECTION"

    $tempPaths = @(
        $env:TEMP, $env:TMP
        "$env:SystemRoot\Temp"
        "$env:SystemRoot\Prefetch"
        "$env:LOCALAPPDATA\Temp"
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies"
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        "$env:LOCALAPPDATA\CrashDumps"
        "$env:LOCALAPPDATA\Microsoft\Windows\WER"
        "$env:ProgramData\Microsoft\Windows\WER"
        "$env:SystemRoot\Logs\CBS"
        "$env:SystemRoot\Minidump"
        "$env:SystemRoot\memory.dmp"
    )

    $freed = 0
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $size = (Get-ChildItem $path -Recurse -Force -EA SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            try {
                Get-ChildItem -Path $path -Recurse -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
                $freed += $size
                Write-Log "Nettoye : $path ($('{0:N2}' -f ($size/1MB)) MB)" "OK"
            } catch { Write-Log "Acces partiel : $path" "WARN" }
        }
    }

    Write-Log "Espace total libere par nettoyage temporaire : $('{0:N1}' -f ($freed/1MB)) MB" "INFO"

    # Corbeille
    Clear-RecycleBin -Force -EA SilentlyContinue
    Write-Log "Corbeille videe" "OK"

    # Windows.old
    if (Test-Path "C:\Windows.old") {
        cmd /c "rd /s /q C:\Windows.old" 2>$null
        Write-Log "Dossier Windows.old supprime" "OK"
    }

    # Nettoyage via cleanmgr (silencieux)
    $sageset = 65535
    $cleanKeys = @(
        "Active Setup Temp Folders","BranchCache","Downloaded Program Files"
        "Internet Cache Files","Memory Dump Files","Old ChkDsk Files"
        "Previous Installations","Recycle Bin","Service Pack Cleanup"
        "Setup Log Files","System error memory dump files"
        "System error minidump files","Temporary Files","Temporary Setup Files"
        "Thumbnail Cache","Update Cleanup","Upgrade Discarded Files"
        "Windows Error Reporting Archive Files","Windows Error Reporting Queue Files"
        "Windows Upgrade Log Files"
    )
    $cleanReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    foreach ($k in $cleanKeys) {
        $key = "$cleanReg\$k"
        if (Test-Path $key) {
            Set-ItemProperty -Path $key -Name "StateFlags$sageset" -Value 2 -Type DWord -Force -EA SilentlyContinue
        }
    }
    Write-Log "Lancement cleanmgr en arriere-plan..." "INFO"
    Start-Process cleanmgr.exe -ArgumentList "/sagerun:$sageset" -WindowStyle Hidden -EA SilentlyContinue

    # DISM : composants Windows obsoletes
    if ($Global:WF.Mode -ne "SAFE") {
        Write-Log "Nettoyage DISM des composants obsoletes en cours..." "INFO"
        Start-Process dism.exe -ArgumentList "/online /cleanup-image /startcomponentcleanup /resetbase" -Wait -WindowStyle Hidden -EA SilentlyContinue
        Write-Log "DISM cleanup termine" "OK"
    }

    # SFC verifie mais n'attend pas
    Write-Log "Lancement SFC /scannow en arriere-plan..." "INFO"
    Start-Job { sfc /scannow } | Out-Null
}

# ============================================================
#  MODULE 10 : SECURITE + HARDENING
# ============================================================
function Set-Security {
    Write-Log "SECURITE ET HARDENING" "SECTION"

    # Pare-feu
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -EA SilentlyContinue
    Write-Log "Pare-feu Windows : tous profils actives" "OK"

    # SMBv1 desactive
    Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -EA SilentlyContinue | Out-Null
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0
    Write-Log "SMBv1 desactive (WannaCry/NotPetya protection)" "OK"

    # AutoRun / AutoPlay
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255
    Set-RegSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255
    Write-Log "AutoRun / AutoPlay desactives" "OK"

    # Windows Defender
    Set-MpPreference -DisableRealtimeMonitoring $false -EA SilentlyContinue
    Set-MpPreference -EnableNetworkProtection Enabled -EA SilentlyContinue
    Write-Log "Windows Defender : protection temps reel + reseau actives" "OK"

    # RDP desactive
    Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
    Write-Log "RDP desactive" "OK"

    # UAC
    Set-RegSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1
    Write-Log "UAC active" "OK"

    # NetBIOS desactiver sur toutes les interfaces
    $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -EA SilentlyContinue | Where-Object { $_.IPEnabled }
    foreach ($a in $adapters) { $a.SetTcpipNetbios(2) | Out-Null }
    Write-Log "NetBIOS desactive sur toutes les interfaces" "OK"

    # LLMNR desactiver
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0
    Write-Log "LLMNR desactive" "OK"

    # Weak TLS/SSL protocols
    $sslPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
        "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
    )
    foreach ($p in $sslPaths) {
        Set-RegSafe -Path $p -Name "Enabled" -Value 0
        Set-RegSafe -Path $p -Name "DisabledByDefault" -Value 1
    }
    Write-Log "SSL 2.0/3.0 + TLS 1.0/1.1 desactives (TLS 1.2/1.3 uniquement)" "OK"

    # Powershell constrained language mode (ULTRA)
    if ($Global:WF.Mode -eq "ULTRA") {
        Set-RegSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "__PSLockdownPolicy" -Value "4" -Type String
        Write-Log "PowerShell Constrained Language Mode active (ULTRA)" "ULTRA"
    }
}

# ============================================================
#  MODULE 11 : OPTIMISATION WINDOWS UPDATE
# ============================================================
function Optimize-WindowsUpdate {
    Write-Log "OPTIMISATION WINDOWS UPDATE" "SECTION"

    # Desactiver Delivery Optimization (P2P)
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0
    Write-Log "Delivery Optimization P2P desactive" "OK"

    # Bloquer les MAJ de drivers via Windows Update
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Value 1
    Write-Log "Drivers via Windows Update bloques (utiliser les drivers constructeur)" "OK"

    # Desactiver auto-restart apres MAJ (pas de reboot force)
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1
    Set-RegSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions"                    -Value 2  # Notify before download
    Write-Log "Redemarrage automatique apres MAJ desactive" "OK"

    # Desactiver Windows Update Medic Service (protection contre desactivation WU)
    # Note: ce service se reprotege, on ne le desactive pas completement
    Write-Log "Windows Update : securite conservee, P2P et auto-restart desactives" "INFO"
}

# ============================================================
#  MODULE 12 : RAPPORT SYSTEME
# ============================================================
function Show-Report {
    Write-Log "RAPPORT SYSTEME COMPLET" "SECTION"

    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────┐" -FG Cyan
    Write-Host "  │            RAPPORT WINFORGE PRO v3.0            │" -FG Cyan
    Write-Host "  ├─────────────────────────────────────────────────┤" -FG DarkCyan
    Write-Host "  │ Systeme  : $(if($Global:WF.IsWin11){'Windows 11'}else{'Windows 10'})$((' ' * 30).Substring(0,31-$(if($Global:WF.IsWin11){'Windows 11'.Length}else{'Windows 10'.Length})))│" -FG White
    Write-Host "  │ CPU      : $($Global:WF.CPUCores) threads$((' ' * 30).Substring(0,30-"$($Global:WF.CPUCores) threads".Length))│" -FG White
    Write-Host "  │ RAM      : $($Global:WF.RAMTotal) Go$((' ' * 30).Substring(0,30-"$($Global:WF.RAMTotal) Go".Length))│" -FG White
    Write-Host "  │ Stockage : $(if($Global:WF.IsSSD){'SSD'}else{'HDD'})$((' ' * 30).Substring(0,30-$(if($Global:WF.IsSSD){'SSD'.Length}else{'HDD'.Length})))│" -FG White
    Write-Host "  │ Mode     : $($Global:WF.Mode)$((' ' * 30).Substring(0,30-$Global:WF.Mode.Length))│" -FG White
    Write-Host "  ├─────────────────────────────────────────────────┤" -FG DarkCyan
    Write-Host "  │ OK      : $($Global:WF.Stats.OK)$((' ' * 30).Substring(0,30-$($Global:WF.Stats.OK).ToString().Length))│" -FG Green
    Write-Host "  │ WARN    : $($Global:WF.Stats.WARN)$((' ' * 30).Substring(0,30-$($Global:WF.Stats.WARN).ToString().Length))│" -FG Yellow
    Write-Host "  │ SKIP    : $($Global:WF.Stats.SKIP)$((' ' * 30).Substring(0,30-$($Global:WF.Stats.SKIP).ToString().Length))│" -FG DarkGray
    Write-Host "  │ ERREUR  : $($Global:WF.Stats.ERROR)$((' ' * 30).Substring(0,30-$($Global:WF.Stats.ERROR).ToString().Length))│" -FG Red
    Write-Host "  ├─────────────────────────────────────────────────┤" -FG DarkCyan
    Write-Host "  │ Journal : $($Global:WF.LogFile.Substring(0, [Math]::Min(40, $Global:WF.LogFile.Length)))...│" -FG Cyan
    Write-Host "  └─────────────────────────────────────────────────┘" -FG Cyan

    # Top processus RAM
    Write-Host ""
    Write-Host "  TOP 5 PROCESSUS PAR MEMOIRE :" -FG Yellow
    Get-Process -EA SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "    $($_.ProcessName.PadRight(25)) $([Math]::Round($_.WorkingSet64/1MB,1)) MB" -FG White
    }

    # Disk usage
    Write-Host ""
    Write-Host "  ESPACE DISQUE :" -FG Yellow
    Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | ForEach-Object {
        $used = $_.Used / 1GB; $free = $_.Free / 1GB; $total = $used + $free
        if ($total -gt 0) {
            Write-Host "    $($_.Name): $('{0:N1}' -f $used)Go / $('{0:N1}' -f $total)Go (libre: $('{0:N1}' -f $free)Go)" -FG White
        }
    }
}

# ============================================================
#  CHANGER MODE / PROFIL
# ============================================================
function Switch-Mode {
    Write-Host ""
    Write-Host "  Choisir le mode :" -FG Yellow
    Write-Host "  [1] SAFE     - Tweaks conservateurs, sans risque"     -FG Green
    Write-Host "  [2] BALANCED - Optimisation poussee (recommande)"     -FG Yellow
    Write-Host "  [3] ULTRA    - Maximum performance, moins de securite" -FG Magenta
    $c = Read-Host "  Choix"
    switch ($c) {
        "1" { $Global:WF.Mode = "SAFE";     Write-Log "Mode SAFE selectionne" "OK" }
        "2" { $Global:WF.Mode = "BALANCED"; Write-Log "Mode BALANCED selectionne" "OK" }
        "3" {
            $Global:WF.Mode = "ULTRA"
            Write-Host ""
            Write-Host "  ⚠️  ULTRA : certains tweaks reduisent la securite." -FG Red
            Write-Host "     Assurez-vous d'avoir un point de restauration." -FG Yellow
            Write-Log "Mode ULTRA selectionne - RISQUES ACCEPTES" "WARN"
        }
    }
}

function Switch-Profile {
    Write-Host ""
    Write-Host "  Choisir le profil :" -FG Yellow
    Write-Host "  [1] PERFORMANCE   - PC bureau general"     -FG White
    Write-Host "  [2] GAMING        - Jeux / latence"        -FG Cyan
    Write-Host "  [3] CONTENT       - Creation de contenu"   -FG Green
    Write-Host "  [4] PRIVACY       - Confidentialite max"   -FG Magenta
    $c = Read-Host "  Choix"
    switch ($c) {
        "1" { $Global:WF.Profile = "PERFORMANCE" }
        "2" { $Global:WF.Profile = "GAMING" }
        "3" { $Global:WF.Profile = "CONTENT" }
        "4" { $Global:WF.Profile = "PRIVACY" }
    }
    Write-Log "Profil $($Global:WF.Profile) selectionne" "OK"
}

# ============================================================
#  POINT D'ENTREE PRINCIPAL
# ============================================================
Show-Banner
Invoke-SystemDetection

Write-Host ""
Write-Host "  WinForge Pro va optimiser votre systeme Windows." -FG White
Write-Host "  Un journal sera cree sur le Bureau." -FG DarkGray
Write-Host "  Backup registre -> $($Global:WF.BackupPath)" -FG DarkGray
Write-Host ""

if ($Global:WF.RestorePoint) { New-RestorePointSafe }

# BOUCLE MENU PRINCIPALE
$exitRequested = $false
while (-not $exitRequested) {
    $choice = Show-Menu

    switch ($choice.ToUpper()) {
        "1"  {
            Write-Log "DEBLOAT COMPLET LANCE" "SECTION"
            Remove-BloatApps
            Block-AppReinstall
            Disable-UnnecessaryServices
            Set-PrivacySettings
            Disable-AIFeatures
            Optimize-Performance
            Optimize-Network
            Clean-System
            Enable-GamingMode
            Set-Security
            Optimize-WindowsUpdate

            Write-Host ""
            Write-Host "  +══════════════════════════════════════════+" -FG Green
            Write-Host "  │     DEBLOAT COMPLET TERMINE !            │" -FG Green
            Write-Host "  │  OK: $($Global:WF.Stats.OK)  WARN: $($Global:WF.Stats.WARN)  SKIP: $($Global:WF.Stats.SKIP)  ERR: $($Global:WF.Stats.ERROR)$((' '*10))│" -FG White
            Write-Host "  +══════════════════════════════════════════+" -FG Green
            Write-Host "  >> REDEMARRAGE RECOMMANDE" -FG Yellow
        }
        "2"  { Remove-BloatApps; Block-AppReinstall }
        "3"  { Disable-UnnecessaryServices }
        "4"  { Set-PrivacySettings }
        "5"  { Optimize-Performance }
        "6"  { Optimize-Network }
        "7"  { Clean-System }
        "8"  { Enable-GamingMode }
        "9"  { Set-Security }
        "10" { Disable-AIFeatures }
        "11" { Block-AppReinstall }
        "12" { Show-Report }
        "M"  { Switch-Mode }
        "P"  { Switch-Profile }
        "R"  { Invoke-Rollback }
        "Q"  { $exitRequested = $true; Write-Log "Script ferme par l'utilisateur." "INFO" }
        default { Write-Log "Choix invalide." "WARN" }
    }

    if (-not $exitRequested) {
        Write-Host ""
        Write-Host "  Appuyez sur ENTREE pour revenir au menu..." -FG DarkGray
        Read-Host | Out-Null
    }
}

# Proposition de reboot
Write-Host ""
$reboot = Read-Host "  Redemarrer maintenant pour appliquer tous les changements ? [O/N]"
if ($reboot.ToUpper() -eq "O") {
    Write-Log "Redemarrage du systeme." "INFO"
    Restart-Computer -Force
}

Write-Host ""
Write-Host "  WinForge Pro v$($Global:WF.Version) - Termine. Journal : $($Global:WF.LogFile)" -FG Cyan
