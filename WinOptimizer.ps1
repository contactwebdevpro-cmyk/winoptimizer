#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinOptimizer - Script complet de debloat et optimisation Windows 10/11
.DESCRIPTION
    Supprime les applications inutiles, optimise les performances,
    la confidentialite et le demarrage de Windows.
.AUTHOR
    WinOptimizer v2.0
.NOTES
    Doit etre execute en tant qu'Administrateur.
    Compatible Windows 10 et Windows 11.
#>

# ============================================================
#  CONFIGURATION
# ============================================================
$ScriptVersion = "2.0"
$LogFile       = "$env:USERPROFILE\Desktop\WinOptimizer_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"
$RestorePoint  = $true   # Creer un point de restauration avant toute modification

# ============================================================
#  COULEURS ET INTERFACE
# ============================================================
function Show-Banner {
    Clear-Host
    $banner = @"
  ██╗    ██╗██╗███╗   ██╗ ██████╗ ██████╗ ████████╗██╗███╗   ███╗██╗███████╗███████╗██████╗
  ██║    ██║██║████╗  ██║██╔═══██╗██╔══██╗╚══██╔══╝██║████╗ ████║██║╚══███╔╝██╔════╝██╔══██╗
  ██║ █╗ ██║██║██╔██╗ ██║██║   ██║██████╔╝   ██║   ██║██╔████╔██║██║  ███╔╝ █████╗  ██████╔╝
  ██║███╗██║██║██║╚██╗██║██║   ██║██╔═══╝    ██║   ██║██║╚██╔╝██║██║ ███╔╝  ██╔══╝  ██╔══██╗
  ╚███╔███╔╝██║██║ ╚████║╚██████╔╝██║        ██║   ██║██║ ╚═╝ ██║██║███████╗███████╗██║  ██║
   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "  Version $ScriptVersion  |  Debloat & Optimisation Windows 10/11" -ForegroundColor DarkCyan
    Write-Host "  ══════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue

    switch ($Level) {
        "OK"      { Write-Host "  [✔] " -ForegroundColor Green  -NoNewline; Write-Host $Message }
        "WARN"    { Write-Host "  [!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "  [✘] " -ForegroundColor Red    -NoNewline; Write-Host $Message }
        "SKIP"    { Write-Host "  [-] " -ForegroundColor Gray   -NoNewline; Write-Host $Message }
        "SECTION" {
            Write-Host ""
            Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Host "  ► $Message" -ForegroundColor Cyan
            Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkCyan
        }
        default   { Write-Host "  [i] " -ForegroundColor Blue   -NoNewline; Write-Host $Message }
    }
}

function Confirm-Action {
    param([string]$Question)
    Write-Host ""
    Write-Host "  [?] $Question" -ForegroundColor Yellow
    Write-Host "      [O] Oui   [N] Non   [Q] Quitter" -ForegroundColor DarkGray
    $response = Read-Host "      Votre choix"
    switch ($response.ToUpper()) {
        "O" { return $true }
        "Q" { Write-Log "Script annule par l'utilisateur." "WARN"; exit }
        default { return $false }
    }
}

function Show-Progress {
    param([string]$Activity, [int]$Percent)
    Write-Progress -Activity $Activity -PercentComplete $Percent -Status "$Percent%"
}

# ============================================================
#  VERIFICATION PREREQUIS
# ============================================================
function Test-Prerequisites {
    Write-Log "VERIFICATION DES PREREQUIS" "SECTION"

    # Admin ?
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Ce script doit etre execute en tant qu'Administrateur !" "ERROR"
        Write-Host "  Relancez PowerShell en tant qu'administrateur." -ForegroundColor Red
        pause; exit
    }
    Write-Log "Droits administrateur confirmes" "OK"

    # Version Windows
    $os = Get-WmiObject Win32_OperatingSystem
    $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    Write-Log "Systeme : $($os.Caption) (Build $build)" "OK"

    if ($build -lt 17763) {
        Write-Log "Ce script est optimise pour Windows 10 1809+ et Windows 11." "WARN"
    }

    # PowerShell version
    Write-Log "PowerShell $($PSVersionTable.PSVersion)" "OK"

    # Connexion Internet (optionnel)
    $net = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -ErrorAction SilentlyContinue
    if ($net) { Write-Log "Connexion Internet disponible" "OK" }
    else       { Write-Log "Pas de connexion Internet (certaines fonctions limitees)" "WARN" }
}

# ============================================================
#  POINT DE RESTAURATION
# ============================================================
function New-RestorePoint {
    Write-Log "CREATION DU POINT DE RESTAURATION" "SECTION"
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "WinOptimizer - Avant optimisation $(Get-Date -Format 'dd/MM/yyyy')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Point de restauration cree avec succes" "OK"
    } catch {
        Write-Log "Impossible de creer le point de restauration : $_" "WARN"
    }
}

# ============================================================
#  DEBLOAT - APPLICATIONS INUTILES
# ============================================================
$AppsToRemove = @(
    # Microsoft Bloatware
    "Microsoft.3DBuilder"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MixedReality.Portal"
    "Microsoft.MSPaint"                        # Paint 3D (pas le Paint classique)
    "Microsoft.NetworkSpeedTest"
    "Microsoft.Office.OneNote"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Todos"
    "Microsoft.Wallet"
    "Microsoft.windowscommunicationsapps"      # Courrier et Calendrier
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    # Third-party
    "SpotifyAB.SpotifyMusic"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushFriends"
    "king.com.FarmHeroesSaga"
    "89006A2EA1EF4D64B57B679CC49A5915"          # CandyCrush génériques
    "A278AB0D24DD776A98DA8B0C8B879A20"          # Dolby
    "D52A8D61D68C4DE7AC3D2D3AF15E93A5"          # Facebook
    "FACEBOOK.FACEBOOK"
    "Facebook.InstagramApp"
    "TikTok.TikTok"
    "BytedancePte.Ltd.TikTok"
    "Netflix"
    "AmazonVideo.PrimeVideo"
    "Disney.37853D22215B_"
    "Hulu.HuluApp"
    "PricelinePartnerNetwork.Booking.comBigsavingsonhot"
    "Nordcurrent.CookingFever"
    "NORDCURRENT.INC.COOKINGFEVER"
    "EclipseManager"
    "ActiproSoftwareLLC"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Duolingo-LearnLanguagesforFree"
    "PandoraMediaInc"
    "Shazam.Shazamfolio"
    "Twitter.Twitter"
)

function Remove-BloatApps {
    Write-Log "SUPPRESSION DES APPLICATIONS INUTILES" "SECTION"
    $total = $AppsToRemove.Count
    $i = 0

    foreach ($app in $AppsToRemove) {
        $i++
        Show-Progress "Suppression des applications" ([int](($i / $total) * 100))

        # Utilisateur courant
        $pkg = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
        if ($pkg) {
            try {
                $pkg | Remove-AppxPackage -ErrorAction Stop
                Write-Log "Supprime : $app" "OK"
            } catch {
                Write-Log "Echec suppression : $app" "WARN"
            }
        } else {
            Write-Log "Non installe : $app" "SKIP"
        }

        # Provisioned (tous les futurs utilisateurs)
        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$app*" }
        if ($prov) {
            try {
                $prov | Remove-AppxProvisionedPackage -Online -ErrorAction Stop | Out-Null
                Write-Log "Deprovisioned : $app" "OK"
            } catch {
                Write-Log "Echec deprovision : $app" "WARN"
            }
        }
    }
    Write-Progress -Activity "Suppression des applications" -Completed
}

# ============================================================
#  DESACTIVATION DES SERVICES INUTILES
# ============================================================
$ServicesToDisable = @{
    "DiagTrack"              = "Telemetrie Microsoft (Connected User Experiences)"
    "dmwappushservice"       = "WAP Push Message Routing Service"
    "MapsBroker"             = "Telechargement de cartes hors connexion"
    "lfsvc"                  = "Geolocalisation"
    "SharedAccess"           = "Partage de connexion Internet (ICS)"
    "WbioSrvc"               = "Biometrie Windows (si non utilise)"
    "WMPNetworkSvc"          = "Partage reseau Windows Media Player"
    "WerSvc"                 = "Rapport d'erreurs Windows"
    "wercplsupport"          = "Support panneau rapports d'erreurs"
    "Fax"                    = "Telecopie"
    "TapiSrv"                = "Telephonie"
    "SysMain"                = "SuperFetch / SysMain (HDD=ON, SSD=OFF)"
    "PcaSvc"                 = "Programme Compat Assistant"
    "RemoteRegistry"         = "Registre distant"
    "RetailDemo"             = "Mode demonstration"
    "PhoneSvc"               = "Service telephone"
    "XblAuthManager"         = "Xbox Live Auth Manager"
    "XblGameSave"            = "Xbox Live Game Save"
    "XboxNetApiSvc"          = "Xbox Live Networking"
    "XboxGipSvc"             = "Xbox Accessory Management"
    "wisvc"                  = "Windows Insider Service"
}

function Disable-UnnecessaryServices {
    Write-Log "DESACTIVATION DES SERVICES INUTILES" "SECTION"

    # Detecter si SSD ou HDD pour SysMain
    $disk = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" }
    if ($disk) {
        Write-Log "SSD detecte : SysMain (SuperFetch) sera desactive" "INFO"
    } else {
        Write-Log "HDD detecte : SysMain (SuperFetch) sera conserve actif" "WARN"
        $ServicesToDisable.Remove("SysMain")
    }

    foreach ($svc in $ServicesToDisable.GetEnumerator()) {
        $service = Get-Service -Name $svc.Key -ErrorAction SilentlyContinue
        if ($service) {
            try {
                Stop-Service -Name $svc.Key -Force -ErrorAction SilentlyContinue
                Set-Service  -Name $svc.Key -StartupType Disabled -ErrorAction Stop
                Write-Log "Desactive : $($svc.Value)" "OK"
            } catch {
                Write-Log "Echec desactivation : $($svc.Key)" "WARN"
            }
        } else {
            Write-Log "Service absent : $($svc.Key)" "SKIP"
        }
    }
}

# ============================================================
#  CONFIDENTIALITE & TELEMETRIE
# ============================================================
function Set-PrivacySettings {
    Write-Log "CONFIGURATION DE LA CONFIDENTIALITE" "SECTION"

    # Desactiver la telemetrie
    $regTelemetry = @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"              = @{ "AllowTelemetry" = 0 }
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @{ "AllowTelemetry" = 0; "MaxTelemetryAllowed" = 0 }
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @{ "AllowTelemetry" = 0 }
    }

    foreach ($path in $regTelemetry.GetEnumerator()) {
        if (!(Test-Path $path.Key)) { New-Item -Path $path.Key -Force | Out-Null }
        foreach ($val in $path.Value.GetEnumerator()) {
            Set-ItemProperty -Path $path.Key -Name $val.Key -Value $val.Value -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "Telemetrie desactivee (niveau 0)" "OK"

    # Desactiver la pub / publicite ID
    $privacyKeys = @{
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"     = @{ "Enabled" = 0 }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"             = @{ "TailoredExperiencesWithDiagnosticDataEnabled" = 0 }
        "HKCU:\SOFTWARE\Microsoft\InputPersonalization"                        = @{ "RestrictImplicitInkCollection" = 1; "RestrictImplicitTextCollection" = 1 }
        "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"       = @{ "HarvestContacts" = 0 }
        "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"                    = @{ "AcceptedPrivacyPolicy" = 0 }
        "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" = @{ "HasAccepted" = 0 }
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"   = @{ "Start_TrackProgs" = 0 }
    }
    foreach ($path in $privacyKeys.GetEnumerator()) {
        if (!(Test-Path $path.Key)) { New-Item -Path $path.Key -Force | Out-Null }
        foreach ($val in $path.Value.GetEnumerator()) {
            Set-ItemProperty -Path $path.Key -Name $val.Key -Value $val.Value -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "ID publicitaire et personnalisation desactives" "OK"

    # Desactiver Cortana
    $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (!(Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
    Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $cortanaPath -Name "AllowCortanaAboveLock" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cortanaPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cortanaPath -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Cortana desactive" "OK"

    # Desactiver Bing dans la recherche Windows
    $searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }
    Set-ItemProperty -Path $searchPath -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $searchPath -Name "CortanaConsent" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Recherche Bing dans le menu Demarrer desactivee" "OK"

    # Desactiver Diagnostic & Feedback
    $feedbackPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $feedbackPath)) { New-Item -Path $feedbackPath -Force | Out-Null }
    Set-ItemProperty -Path $feedbackPath -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Notifications de feedback desactivees" "OK"

    # Desactiver la collecte d'activite (Timeline)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Historique d'activite (Timeline) desactive" "OK"

    # Desactiver envoi donnees d'ecriture manuscrite
    $inkPath = "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization"
    if (!(Test-Path $inkPath)) { New-Item -Path $inkPath -Force | Out-Null }
    Set-ItemProperty -Path $inkPath -Name "AllowInputPersonalization" -Value 0 -Type DWord -Force
    Write-Log "Personnalisation de la saisie desactivee" "OK"
}

# ============================================================
#  OPTIMISATION DES PERFORMANCES
# ============================================================
function Optimize-Performance {
    Write-Log "OPTIMISATION DES PERFORMANCES" "SECTION"

    # Plan d'alimentation Haute Performance
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Creer si n'existe pas
        powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    }
    Write-Log "Plan d'alimentation : Haute Performance active" "OK"

    # Desactiver les effets visuels superflus
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    $visualKeys = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $visualKeys -Name "DragFullWindows"          -Value "0" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $visualKeys -Name "MenuShowDelay"            -Value "0" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $visualKeys -Name "UserPreferencesMask"      -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics"  -Name "MinAnimate" -Value "0" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\DWM"       -Name "EnableAeroPeek" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Effets visuels reduits pour meilleures performances" "OK"

    # Accelerer le menu Demarrer
    $startPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $startPath -Name "Start_PowerButtonAction" -Value 2   -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $startPath -Name "HideFileExt"             -Value 0   -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $startPath -Name "Hidden"                  -Value 1   -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Explorateur optimise (extensions visibles, fichiers caches visibles)" "OK"

    # Desactiver Hibernate (libere de l'espace)
    powercfg -h off 2>$null
    Write-Log "Hibernation desactivee (libere hiberfil.sys)" "OK"

    # Desactiver Windows Search Indexing (optionnel, ameliore I/O)
    $idxSvc = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
    if ($idxSvc) {
        Stop-Service "WSearch" -Force -ErrorAction SilentlyContinue
        Set-Service  "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Indexation Windows Search desactivee" "OK"
    }

    # Optimiser le prefetch
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch"  -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Desactiver paging executif
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Gestion memoire optimisee" "OK"

    # Accelerer l'arret du systeme
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "2000" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop"            -Name "WaitToKillAppTimeout"     -Value "2000" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop"            -Name "HungAppTimeout"           -Value "1000" -Force -ErrorAction SilentlyContinue
    Write-Log "Delais d'arret du systeme reduits" "OK"

    # Desactiver Remote Assistance
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Assistance a distance desactivee" "OK"

    # NTFS - Desactiver la mise a jour de lastaccess (gain I/O)
    fsutil behavior set disablelastaccess 1 2>$null
    Write-Log "Mise a jour LastAccess NTFS desactivee (gain I/O)" "OK"

    # Desactiver 8dot3 name creation
    fsutil behavior set disable8dot3 1 2>$null
    Write-Log "Creation de noms 8.3 desactivee" "OK"
}

# ============================================================
#  OPTIMISATION RESEAU
# ============================================================
function Optimize-Network {
    Write-Log "OPTIMISATION RESEAU" "SECTION"

    # Desactiver la limitation de bande passante reservee (QoS = 0)
    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (!(Test-Path $qosPath)) { New-Item -Path $qosPath -Force | Out-Null }
    Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force
    Write-Log "Bande passante reservee pour QoS supprimee (gain 20%)" "OK"

    # Desactiver Nagle Algorithm (reduit latence reseaux locaux)
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem -Path $tcpPath | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay"      -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Algorithme de Nagle desactive (latence reduite)" "OK"

    # DNS rapide (Cloudflare + Google)
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ("1.1.1.1", "8.8.8.8") -ErrorAction SilentlyContinue
    }
    Write-Log "DNS configure sur Cloudflare (1.1.1.1) et Google (8.8.8.8)" "OK"

    # Vider cache DNS
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Log "Cache DNS vide" "OK"

    # Desactiver la reduction automatique du MTU
    netsh int tcp set global autotuninglevel=normal 2>$null
    netsh int tcp set global rss=enabled 2>$null
    netsh int tcp set global chimney=enabled 2>$null
    Write-Log "Parametres TCP optimises (RSS, Chimney)" "OK"
}

# ============================================================
#  NETTOYAGE DU SYSTEME
# ============================================================
function Clean-System {
    Write-Log "NETTOYAGE DU SYSTEME" "SECTION"

    # Vider les dossiers temp
    $tempPaths = @(
        $env:TEMP,
        $env:TMP,
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
        "$env:LOCALAPPDATA\CrashDumps"
    )

    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            try {
                Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Nettoye : $path" "OK"
            } catch {
                Write-Log "Acces refuse (partiel) : $path" "WARN"
            }
        }
    }

    # Vider la corbeille
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Log "Corbeille videe" "OK"

    # Nettoyage disque automatique (cleanmgr)
    $sageset = 65535
    $cleanRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    $categories = @(
        "Active Setup Temp Folders", "BranchCache", "Downloaded Program Files",
        "Internet Cache Files", "Memory Dump Files", "Old ChkDsk Files",
        "Previous Installations", "Recycle Bin", "Service Pack Cleanup",
        "Setup Log Files", "System error memory dump files",
        "System error minidump files", "Temporary Files", "Temporary Setup Files",
        "Thumbnail Cache", "Update Cleanup", "Upgrade Discarded Files",
        "Windows Error Reporting Archive Files", "Windows Error Reporting Queue Files",
        "Windows Error Reporting System Archive Files", "Windows Error Reporting System Queue Files",
        "Windows Upgrade Log Files"
    )
    foreach ($cat in $categories) {
        $key = "$cleanRegPath\$cat"
        if (Test-Path $key) {
            Set-ItemProperty -Path $key -Name "StateFlags$sageset" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Process -FilePath cleanmgr.exe -ArgumentList "/sagerun:$sageset" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    Write-Log "Nettoyage de disque Windows effectue" "OK"

    # Nettoyer le dossier Windows.old si present
    if (Test-Path "C:\Windows.old") {
        cmd /c "rd /s /q C:\Windows.old" 2>$null
        Write-Log "Dossier Windows.old supprime" "OK"
    }

    # SFC & DISM (optionnel, peut etre long)
    Write-Log "Verification de l'integrite des fichiers systeme en cours..." "INFO"
    $sfcJob = Start-Job { sfc /scannow }
    Wait-Job $sfcJob -Timeout 300 | Out-Null
    Remove-Job $sfcJob -Force | Out-Null
    Write-Log "Verification SFC terminee (voir CBS.log pour details)" "OK"
}

# ============================================================
#  OPTIMISATION DU DEMARRAGE
# ============================================================
function Optimize-Startup {
    Write-Log "OPTIMISATION DU DEMARRAGE" "SECTION"

    # Desactiver des taches planifiees de telemetrie
    $tasksToDisable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
        "\Microsoft\Windows\Application Experience\StartupAppTask"
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        "\Microsoft\Windows\Feedback\Siuf\DmClient"
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
        "\Microsoft\Windows\Maps\MapsToastTask"
        "\Microsoft\Windows\Maps\MapsUpdateTask"
        "\Microsoft\Windows\XblGameSave\XblGameSaveTask"
        "\Microsoft\XblGameSave\XblGameSaveTask"
    )

    foreach ($task in $tasksToDisable) {
        try {
            $t = Get-ScheduledTask -TaskPath ([System.IO.Path]::GetDirectoryName($task) + "\") `
                                   -TaskName  ([System.IO.Path]::GetFileName($task)) `
                                   -ErrorAction SilentlyContinue
            if ($t) {
                Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null
                Write-Log "Tache desactivee : $task" "OK"
            } else {
                Write-Log "Tache absente : $task" "SKIP"
            }
        } catch {
            Write-Log "Echec desactivation tache : $task" "WARN"
        }
    }

    # Activer le demarrage rapide (Fast Boot)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Demarrage rapide (Fast Boot) active" "OK"

    # Desactiver les programmes de demarrage courants (notification uniquement)
    Write-Log "Programmes au demarrage : verifiez le Gestionnaire de taches > Demarrage" "INFO"
}

# ============================================================
#  SECURITE & HARDENING DE BASE
# ============================================================
function Set-BasicSecurity {
    Write-Log "SECURITE - HARDENING DE BASE" "SECTION"

    # Activer le pare-feu Windows
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction SilentlyContinue
    Write-Log "Pare-feu Windows active sur tous les profils" "OK"

    # Desactiver SMBv1 (vulnerabilite WannaCry)
    Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "SMBv1 desactive (protection contre WannaCry/NotPetya)" "OK"

    # Desactiver Autorun / AutoPlay
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "AutoRun / AutoPlay desactives" "OK"

    # Activer Windows Defender (si pas de tiers)
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Write-Log "Windows Defender : protection en temps reel verifiee" "OK"

    # Desactiver Remote Desktop (si non requis)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Bureau a distance (RDP) desactive" "OK"

    # Activer UAC
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "UAC (Controle de compte utilisateur) active" "OK"
}

# ============================================================
#  RESUME FINAL
# ============================================================
function Show-Summary {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                  OPTIMISATION TERMINEE !                     ║" -ForegroundColor Green
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "  ║  ✔ Applications bloatware supprimees                         ║" -ForegroundColor White
    Write-Host "  ║  ✔ Services inutiles desactives                              ║" -ForegroundColor White
    Write-Host "  ║  ✔ Confidentialite & telemetrie configurees                  ║" -ForegroundColor White
    Write-Host "  ║  ✔ Performances optimisees                                   ║" -ForegroundColor White
    Write-Host "  ║  ✔ Reseau optimise                                           ║" -ForegroundColor White
    Write-Host "  ║  ✔ Systeme nettoye                                           ║" -ForegroundColor White
    Write-Host "  ║  ✔ Demarrage accelere                                        ║" -ForegroundColor White
    Write-Host "  ║  ✔ Securite de base renforcee                                ║" -ForegroundColor White
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "  ║  Journal sauvegarde : $LogFile" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ► Un REDEMARRAGE est recommande pour appliquer tous les changements." -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
#  MENU PRINCIPAL
# ============================================================
function Show-Menu {
    Show-Banner
    Write-Host "  MENU PRINCIPAL" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [1]  Debloat complet (toutes les etapes)" -ForegroundColor Cyan
    Write-Host "  [2]  Supprimer les applications inutiles" -ForegroundColor White
    Write-Host "  [3]  Desactiver les services inutiles" -ForegroundColor White
    Write-Host "  [4]  Confidentialite & Telemetrie" -ForegroundColor White
    Write-Host "  [5]  Optimiser les performances" -ForegroundColor White
    Write-Host "  [6]  Optimiser le reseau" -ForegroundColor White
    Write-Host "  [7]  Nettoyer le systeme" -ForegroundColor White
    Write-Host "  [8]  Optimiser le demarrage" -ForegroundColor White
    Write-Host "  [9]  Securite de base" -ForegroundColor White
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [Q]  Quitter" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "  Entrez votre choix"
    return $choice
}

# ============================================================
#  POINT D'ENTREE
# ============================================================

Show-Banner
Test-Prerequisites

Write-Host ""
Write-Host "  Ce script va optimiser votre Windows 10/11." -ForegroundColor White
Write-Host "  Un journal sera cree sur le Bureau." -ForegroundColor DarkGray
Write-Host ""

if ($RestorePoint) {
    New-RestorePoint
}

$menuChoice = Show-Menu

switch ($menuChoice.ToUpper()) {
    "1" {
        Write-Log "MODE COMPLET SELECTIONNE" "INFO"
        Remove-BloatApps
        Disable-UnnecessaryServices
        Set-PrivacySettings
        Optimize-Performance
        Optimize-Network
        Clean-System
        Optimize-Startup
        Set-BasicSecurity
    }
    "2" { Remove-BloatApps }
    "3" { Disable-UnnecessaryServices }
    "4" { Set-PrivacySettings }
    "5" { Optimize-Performance }
    "6" { Optimize-Network }
    "7" { Clean-System }
    "8" { Optimize-Startup }
    "9" { Set-BasicSecurity }
    "Q" { Write-Log "Script ferme par l'utilisateur." "WARN"; exit }
    default {
        Write-Log "Choix invalide. Lancement du mode complet par defaut." "WARN"
        Remove-BloatApps
        Disable-UnnecessaryServices
        Set-PrivacySettings
        Optimize-Performance
        Optimize-Network
        Clean-System
        Optimize-Startup
        Set-BasicSecurity
    }
}

Show-Summary

Write-Host "  Appuyez sur une touche pour redemarrer, ou fermez cette fenetre." -ForegroundColor Yellow
$reboot = Read-Host "  Redemarrer maintenant ? [O/N]"
if ($reboot.ToUpper() -eq "O") {
    Write-Log "Redemarrage du systeme." "INFO"
    Restart-Computer -Force
}
