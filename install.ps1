#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinOptimizer - Launcher en ligne
    Ce script est le point d'entree pour "irm URL | iex"
    Il telecharge le script principal et le lance.
#>

# ── Configuration ──────────────────────────────────────────────
$ScriptUrl   = "https://winoptimizer-powershell.vercel.app/WinOptimizer.ps1"
$TempDir     = "$env:TEMP\WinOptimizer"
$ScriptLocal = "$TempDir\WinOptimizer.ps1"

# Après le téléchargement, avant le lancement
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "WinOptimizer/2.0 PowerShell")
$wc.Encoding = [System.Text.Encoding]::UTF8   # ← AJOUTER CETTE LIGNE
$wc.DownloadFile($ScriptUrl, $ScriptLocal)
# ───────────────────────────────────────────────────────────────

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ██╗    ██╗██╗███╗   ██╗ ██████╗ ██████╗ ████████╗██╗███╗   ███╗██╗███████╗███████╗██████╗ " -ForegroundColor Cyan
    Write-Host "  ██║    ██║██║████╗  ██║██╔═══██╗██╔══██╗╚══██╔══╝██║████╗ ████║██║╚══███╔╝██╔════╝██╔══██╗" -ForegroundColor Cyan
    Write-Host "  ██║ █╗ ██║██║██╔██╗ ██║██║   ██║██████╔╝   ██║   ██║██╔████╔██║██║  ███╔╝ █████╗  ██████╔╝" -ForegroundColor Cyan
    Write-Host "  ██║███╗██║██║██║╚██╗██║██║   ██║██╔═══╝    ██║   ██║██║╚██╔╝██║██║ ███╔╝  ██╔══╝  ██╔══██╗" -ForegroundColor Cyan
    Write-Host "  ╚███╔███╔╝██║██║ ╚████║╚██████╔╝██║        ██║   ██║██║ ╚═╝ ██║██║███████╗███████╗██║  ██║" -ForegroundColor Cyan
    Write-Host "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Debloat & Optimisation Windows 10/11 — v2.0" -ForegroundColor DarkCyan
    Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Banner

# ── Vérification droits admin ──
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [!] Ce script necessite des droits Administrateur." -ForegroundColor Red
    Write-Host "      Relancez PowerShell en tant qu'Administrateur." -ForegroundColor Yellow
    Write-Host ""
    pause; exit 1
}
Write-Host "  [✔] Droits Administrateur confirmes" -ForegroundColor Green

# ── Création dossier temp ──
if (!(Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

# ── Téléchargement ──
Write-Host "  [→] Telechargement de WinOptimizer..." -ForegroundColor Cyan

try {
    # Forcer TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "WinOptimizer/2.0 PowerShell")
    $wc.DownloadFile($ScriptUrl, $ScriptLocal)

    if (!(Test-Path $ScriptLocal) -or (Get-Item $ScriptLocal).Length -lt 1000) {
        throw "Fichier telecharge invalide ou trop petit."
    }

    Write-Host "  [✔] Telechargement reussi" -ForegroundColor Green
} catch {
    Write-Host "  [✘] Echec du telechargement : $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Solutions :" -ForegroundColor Yellow
    Write-Host "    1. Verifiez votre connexion Internet" -ForegroundColor Gray
    Write-Host "    2. Telechargez manuellement depuis : $ScriptUrl" -ForegroundColor Gray
    Write-Host ""
    pause; exit 1
}

# ── Lancement ──
Write-Host "  [→] Lancement de WinOptimizer..." -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Milliseconds 600

try {
    & PowerShell -ExecutionPolicy Bypass -NoProfile -File $ScriptLocal
} catch {
    Write-Host "  [✘] Erreur lors de l'execution : $_" -ForegroundColor Red
    pause; exit 1
} finally {
    # Nettoyage du fichier temporaire
    Remove-Item $ScriptLocal -Force -ErrorAction SilentlyContinue
}
