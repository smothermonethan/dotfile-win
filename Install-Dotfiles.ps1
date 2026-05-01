#Requires -Version 7
<#
.SYNOPSIS
    Christian Lempa dotfiles-win full installer
    dotfiles-win : https://github.com/ChristianLempa/dotfiles-win
    hackbox      : https://github.com/ChristianLempa/hackbox

.DESCRIPTION
    Installs and configures:
      1. Scoop package manager
      2. Hack Nerd Font (Regular + Mono)
      3. CLI tools  (starship, git, kubectl, helm, datree)
      4. Windows Terminal tab icons  (git clone smothermonethan/icon)
      5. WSL distros: Ubuntu 20.04, Kali Linux, Arch Linux
      6. Windows Terminal settings.json
           - defaultProfile: Ubuntu Linux
           - xcad_tdl colour scheme (+ hackthebox, tdl_colorful, vscode, etc.)
           - Hack Nerd Font 14pt, opacity 95
           - 5 profiles with per-tab colours and icons8-* icons
           - exact startingDirectory paths with your WSL username
      7. Starship prompt config  (~/.starship/starship.toml)
      8. PowerShell profile  (Microsoft.PowerShell_profile.ps1)
           - aliases k/h/g, goto, kn, Terminal-Icons, PSReadLine, datree completion

.PARAMETER WslUsername
    Your WSL Linux username — baked into the startingDirectory paths in
    settings.json.  Defaults to 'xcad' (Christian Lempa's username).
    Change it to your own:   .\Install-Dotfiles.ps1 -WslUsername "yourname"

.NOTES
    Run from an elevated PowerShell 7 session:
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
        .\Install-Dotfiles.ps1 -WslUsername "yourname"

    Skip individual sections with switches, e.g.:
        .\Install-Dotfiles.ps1 -SkipWsl -SkipFonts
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    # Your WSL Linux username — written into startingDirectory paths.
    # Defaults to 'xcad' (Christian Lempa's username).
    [string]$WslUsername = "xcad",

    [switch]$SkipFonts,
    [switch]$SkipPackages,
    [switch]$SkipWsl,               # skip WSL distro installation
    [switch]$SkipTerminalSettings,
    [switch]$SkipProfile,
    [switch]$SkipStarship
)

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "    [OK]   $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "    [SKIP] $msg" -ForegroundColor DarkGray }
function Write-Warn { param($msg) Write-Host "    [WARN] $msg" -ForegroundColor Yellow }

function Backup-File {
    param([string]$Path)
    if (Test-Path $Path) {
        $backup = "$Path.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $Path -Destination $backup -Force
        Write-Warn "Backed up: $backup"
    }
}

# ── 1. Scoop ──────────────────────────────────────────────────────────────────

Write-Step "Checking Scoop package manager"
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "    Installing Scoop..." -ForegroundColor Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

    # Allow running as Administrator (required when shell is elevated)
    $env:SCOOP_ALLOW_ADMIN = '1'
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

    # Refresh PATH in the current session so 'scoop' is usable immediately
    $scoopShims = "$env:USERPROFILE\scoop\shims"
    if (Test-Path $scoopShims) {
        $env:PATH = "$scoopShims;$env:PATH"
    }

    # Verify scoop is now reachable
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warn "Scoop installed but not found on PATH. Try reopening the shell and re-running."
        exit 1
    }

    Write-OK "Scoop installed"
} else {
    Write-OK "Scoop already installed"
}

# ── 2. Packages ───────────────────────────────────────────────────────────────

if (-not $SkipPackages) {
    Write-Step "Installing required packages via Scoop"

    foreach ($bucket in @("extras", "nerd-fonts")) {
        if (-not (scoop bucket list | Select-String $bucket)) {
            scoop bucket add $bucket
            Write-OK "Added bucket: $bucket"
        } else {
            Write-Skip "Bucket already added: $bucket"
        }
    }

    $packages = @(
        "starship",    # Starship cross-shell prompt
        "git",         # Git version control
        "kubectl",     # Kubernetes CLI  --> alias: k
        "helm",        # Helm CLI        --> alias: h
        "datree"       # Datree CLI (with tab completion)
    )

    foreach ($pkg in $packages) {
        if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
            Write-Host "    Installing $pkg..." -ForegroundColor Yellow
            scoop install $pkg
            Write-OK "$pkg installed"
        } else {
            Write-Skip "$pkg already installed"
        }
    }
} else {
    Write-Skip "Package installation skipped (-SkipPackages)"
}

# ── 3. Hack Nerd Fonts ────────────────────────────────────────────────────────

if (-not $SkipFonts) {
    Write-Step "Installing Hack Nerd Fonts (Mono + Regular)"

    $fonts = @("Hack-NF", "Hack-NF-Mono")
    foreach ($font in $fonts) {
        $installed = (scoop list 2>$null) | Select-String $font
        if (-not $installed) {
            Write-Host "    Installing font: $font" -ForegroundColor Yellow
            scoop install $font
            Write-OK "$font installed"
        } else {
            Write-Skip "$font already installed"
        }
    }
} else {
    Write-Skip "Font installation skipped (-SkipFonts)"
}

# ── 4. Windows Terminal tab icons ─────────────────────────────────────────────

Write-Step "Setting up Windows Terminal tab icons (git clone from smothermonethan/icon)"

$iconsDir  = "$env:USERPROFILE\WindowsTerminalIcons"
$iconsRepo = "https://github.com/smothermonethan/icon.git"

if (Test-Path (Join-Path $iconsDir ".git")) {
    # Repo already cloned — pull latest icons
    Write-Host "    Updating icons repo..." -ForegroundColor Yellow
    Push-Location $iconsDir
    git pull --ff-only 2>&1 | ForEach-Object { Write-Host "    $_" }
    Pop-Location
    Write-OK "Icons repo updated: $iconsDir"
} elseif (Test-Path $iconsDir) {
    # Directory exists but is not a git repo — clone into temp then copy
    Write-Host "    Cloning icons into existing folder..." -ForegroundColor Yellow
    $tmpClone = "$env:TEMP\wt-icons-tmp"
    git clone $iconsRepo $tmpClone 2>&1 | ForEach-Object { Write-Host "    $_" }
    Copy-Item "$tmpClone\*.png" -Destination $iconsDir -Force
    Remove-Item $tmpClone -Recurse -Force
    Write-OK "Icons copied to: $iconsDir"
} else {
    # Fresh clone directly into iconsDir
    Write-Host "    Cloning icons repo..." -ForegroundColor Yellow
    git clone $iconsRepo $iconsDir 2>&1 | ForEach-Object { Write-Host "    $_" }
    Write-OK "Icons repo cloned: $iconsDir"
}

# ── 4b. WSL distros ──────────────────────────────────────────────────────────
#
#  Christian Lempa's three WSL distros (from dotfiles-win settings.json):
#    • Ubuntu 20.04  — default profile, general dev environment
#    • Kali Linux    — security/hacking toolbox (hackbox distro)
#    • Arch Linux    — minimalist rolling-release distro
#
#  Installed via `wsl --install` (Windows 10 2004+ / Windows 11).

if (-not $SkipWsl) {
    Write-Step "Installing WSL distros  (Ubuntu-20.04 · Kali Linux · Arch Linux)"

    # Ensure wsl.exe is present; enable the WSL Windows feature if not
    $wslExe = "$env:SystemRoot\System32\wsl.exe"
    if (-not (Test-Path $wslExe)) {
        Write-Warn "wsl.exe not found — enabling WSL and VirtualMachinePlatform features..."
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        Write-Warn "A reboot is required. Re-run with -SkipFonts -SkipPackages after rebooting."
        exit 0
    }

    # Force WSL 2 as the default
    wsl --set-default-version 2 2>$null
    Write-OK "WSL default version: 2"

    function Test-WslDistro {
        param([string]$Name)
        # --list --quiet outputs bare names, one per line
        $list = wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() -replace '\x00','' }
        return ($list -contains $Name)
    }

    # ── Ubuntu 20.04 ─────────────────────────────────────────────────────────
    if (-not (Test-WslDistro "Ubuntu-20.04")) {
        Write-Host "    Installing Ubuntu 20.04  (may take several minutes)..." -ForegroundColor Yellow
        wsl --install --distribution Ubuntu-20.04 --no-launch
        Write-OK "Ubuntu 20.04 installed"
        Write-Warn "On first launch: create a UNIX user matching -WslUsername '$WslUsername'"
    } else {
        Write-Skip "Ubuntu-20.04 already registered"
    }

    # ── Kali Linux ───────────────────────────────────────────────────────────
    if (-not (Test-WslDistro "kali-linux")) {
        Write-Host "    Installing Kali Linux  (may take several minutes)..." -ForegroundColor Yellow
        wsl --install --distribution kali-linux --no-launch
        Write-OK "Kali Linux installed"
        Write-Warn "On first launch: create a UNIX user matching -WslUsername '$WslUsername'"
        Write-Host "    TIP: After first Kali launch run:" -ForegroundColor DarkCyan
        Write-Host "         sudo apt update && sudo apt install -y kali-linux-default" -ForegroundColor DarkCyan
    } else {
        Write-Skip "kali-linux already registered"
    }

    # ── Arch Linux ───────────────────────────────────────────────────────────
    # Arch is not in the official wsl --list --online catalogue; install via
    # the community yuk7/wsldl Arch tarball or the ArchWSL release.
    if (-not (Test-WslDistro "Arch")) {
        Write-Host "    Installing Arch Linux via ArchWSL..." -ForegroundColor Yellow
        $archDir    = "$env:USERPROFILE\WSL\Arch"
        $archExe    = "$archDir\Arch.exe"
        $archRelUrl = "https://github.com/yuk7/ArchWSL/releases/latest/download/Arch.zip"
        $archZip    = "$env:TEMP\ArchWSL.zip"

        if (-not (Test-Path $archDir)) {
            New-Item -ItemType Directory -Path $archDir -Force | Out-Null
        }

        try {
            Invoke-WebRequest -Uri $archRelUrl -OutFile $archZip -UseBasicParsing -ErrorAction Stop
            Expand-Archive -Path $archZip -DestinationPath $archDir -Force
            Remove-Item $archZip -Force

            # Register / install the distro
            if (Test-Path $archExe) {
                & $archExe
                Write-OK "Arch Linux installed via ArchWSL — follow on-screen setup"
                Write-Warn "Run inside Arch:  useradd -m -G wheel $WslUsername && passwd $WslUsername"
                Write-Warn "Then set as default user:  $archExe config --default-user $WslUsername"
            } else {
                Write-Warn "Arch.exe not found after extraction. Check $archDir manually."
            }
        } catch {
            Write-Warn "ArchWSL download failed ($_)."
            Write-Warn "Install manually: https://github.com/yuk7/ArchWSL/releases"
        }
    } else {
        Write-Skip "Arch already registered"
    }
} else {
    Write-Skip "WSL distro installation skipped (-SkipWsl)"
}

# ── Resolve WSL username for settings.json paths ──────────────────────────────
# Auto-detect from a running Ubuntu instance; fall back to -WslUsername value.
$resolvedWslUser = $WslUsername
try {
    $detected = (wsl -d Ubuntu-20.04 -- whoami 2>$null).Trim() -replace '\x00',''
    if ($detected -and $detected -ne 'root' -and $detected -ne '') {
        $resolvedWslUser = $detected
        if ($resolvedWslUser -ne $WslUsername) {
            Write-Warn "Auto-detected WSL username '$resolvedWslUser'. Pass -WslUsername to override."
        }
    }
} catch { <# distro not running yet — use supplied value #> }
Write-OK "WSL username for startingDirectory paths: $resolvedWslUser"

# ── 5. Windows Terminal settings.json ─────────────────────────────────────────

if (-not $SkipTerminalSettings) {
    Write-Step "Writing Windows Terminal settings (xcad_tdl color scheme + Hack Nerd Font + profiles)"

    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )

    # Exact settings from ChristianLempa/dotfiles-win (generalized WSL paths)
    $wtSettings = @'
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "actions": [],
    "alwaysShowNotificationIcon": false,
    "defaultProfile": "{07b52e3e-de2c-5db4-bd2d-ba144ed6c273}",
    "firstWindowPreference": "defaultProfile",
    "profiles":
    {
        "defaults":
        {
            "colorScheme": "xcad_tdl",
            "font":
            {
                "face": "Hack Nerd Font",
                "size": 14
            },
            "historySize": 12000,
            "opacity": 95,
            "scrollbarState": "visible",
            "useAcrylic": false
        },
        "list":
        [
            {
                "guid": "{07b52e3e-de2c-5db4-bd2d-ba144ed6c273}",
                "hidden": false,
                "icon": "%userprofile%\\WindowsTerminalIcons\\icons8-ubuntu-32.png",
                "name": "Ubuntu Linux",
                "source": "Windows.Terminal.Wsl",
                "startingDirectory": "UBUNTU_DIR_PLACEHOLDER",
                "tabColor": "#080e6d"
            },
            {
                "guid": "{46ca431a-3a87-5fb3-83cd-11ececc031d2}",
                "hidden": false,
                "icon": "%userprofile%\\WindowsTerminalIcons\\icons8-fsociety-mask-32.png",
                "name": "Kali Linux",
                "source": "Windows.Terminal.Wsl",
                "startingDirectory": "KALI_DIR_PLACEHOLDER",
                "tabColor": "#14a8d7"
            },
            {
                "commandline": "wsl.exe -d Arch --user xcad",
                "guid": "{a5a97cb8-8961-5535-816d-772efe0c6a3f}",
                "hidden": false,
                "icon": "%userprofile%\\WindowsTerminalIcons\\icons8-arch-linux-32.png",
                "name": "Arch Linux",
                "source": "Windows.Terminal.Wsl",
                "startingDirectory": "ARCH_DIR_PLACEHOLDER",
                "tabColor": "#0d4f10"
            },
            {
                "commandline": "cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "icon": "%userprofile%\\WindowsTerminalIcons\\icons8-cmd-32.png",
                "name": "Commandline",
                "tabColor": "#142fd7"
            },
            {
                "guid": "{b453ae62-4e3d-5e58-b989-0a998ec441b8}",
                "hidden": true,
                "icon": "%userprofile%\\WindowsTerminalIcons\\icons8-azure-32.png",
                "name": "Azure Cloud Shell",
                "source": "Windows.Terminal.Azure",
                "tabColor": "#a711a6"
            },
            {
                "commandline": "C:\\Program Files\\PowerShell\\7\\pwsh.exe --NoLogo",
                "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "hidden": false,
                "icon": "%userprofile%\\WindowsTerminalIcons\\icons8-powershell-32.png",
                "name": "PowerShell",
                "source": "Windows.Terminal.PowershellCore",
                "tabColor": "#a70bf9"
            }
        ]
    },
    "schemes":
    [
        {
            "background": "#080808",
            "black": "#0A0A0A",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#CCCCCC",
            "green": "#13A10E",
            "name": "Campbell",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#012456",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5",
            "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD",
            "foreground": "#CCCCCC",
            "green": "#13A10E",
            "name": "Campbell Powershell",
            "purple": "#881798",
            "red": "#C50F1F",
            "selectionBackground": "#FFFFFF",
            "white": "#CCCCCC",
            "yellow": "#C19C00"
        },
        {
            "background": "#282C34",
            "black": "#282C34",
            "blue": "#61AFEF",
            "brightBlack": "#5A6374",
            "brightBlue": "#61AFEF",
            "brightCyan": "#56B6C2",
            "brightGreen": "#98C379",
            "brightPurple": "#C678DD",
            "brightRed": "#E06C75",
            "brightWhite": "#DCDFE4",
            "brightYellow": "#E5C07B",
            "cursorColor": "#FFFFFF",
            "cyan": "#56B6C2",
            "foreground": "#DCDFE4",
            "green": "#98C379",
            "name": "One Half Dark",
            "purple": "#C678DD",
            "red": "#E06C75",
            "selectionBackground": "#FFFFFF",
            "white": "#DCDFE4",
            "yellow": "#E5C07B"
        },
        {
            "background": "#FAFAFA",
            "black": "#383A42",
            "blue": "#0184BC",
            "brightBlack": "#4F525D",
            "brightBlue": "#61AFEF",
            "brightCyan": "#56B5C1",
            "brightGreen": "#98C379",
            "brightPurple": "#C577DD",
            "brightRed": "#DF6C75",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#E4C07A",
            "cursorColor": "#4F525D",
            "cyan": "#0997B3",
            "foreground": "#383A42",
            "green": "#50A14F",
            "name": "One Half Light",
            "purple": "#A626A4",
            "red": "#E45649",
            "selectionBackground": "#FFFFFF",
            "white": "#FAFAFA",
            "yellow": "#C18301"
        },
        {
            "background": "#002B36",
            "black": "#002B36",
            "blue": "#268BD2",
            "brightBlack": "#073642",
            "brightBlue": "#839496",
            "brightCyan": "#93A1A1",
            "brightGreen": "#586E75",
            "brightPurple": "#6C71C4",
            "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3",
            "brightYellow": "#657B83",
            "cursorColor": "#FFFFFF",
            "cyan": "#2AA198",
            "foreground": "#839496",
            "green": "#859900",
            "name": "Solarized Dark",
            "purple": "#D33682",
            "red": "#DC322F",
            "selectionBackground": "#FFFFFF",
            "white": "#EEE8D5",
            "yellow": "#B58900"
        },
        {
            "background": "#FDF6E3",
            "black": "#002B36",
            "blue": "#268BD2",
            "brightBlack": "#073642",
            "brightBlue": "#839496",
            "brightCyan": "#93A1A1",
            "brightGreen": "#586E75",
            "brightPurple": "#6C71C4",
            "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3",
            "brightYellow": "#657B83",
            "cursorColor": "#002B36",
            "cyan": "#2AA198",
            "foreground": "#657B83",
            "green": "#859900",
            "name": "Solarized Light",
            "purple": "#D33682",
            "red": "#DC322F",
            "selectionBackground": "#FFFFFF",
            "white": "#EEE8D5",
            "yellow": "#B58900"
        },
        {
            "background": "#000000",
            "black": "#000000",
            "blue": "#3465A4",
            "brightBlack": "#555753",
            "brightBlue": "#729FCF",
            "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234",
            "brightPurple": "#AD7FA8",
            "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC",
            "brightYellow": "#FCE94F",
            "cursorColor": "#FFFFFF",
            "cyan": "#06989A",
            "foreground": "#D3D7CF",
            "green": "#4E9A06",
            "name": "Tango Dark",
            "purple": "#75507B",
            "red": "#CC0000",
            "selectionBackground": "#FFFFFF",
            "white": "#D3D7CF",
            "yellow": "#C4A000"
        },
        {
            "background": "#FFFFFF",
            "black": "#000000",
            "blue": "#3465A4",
            "brightBlack": "#555753",
            "brightBlue": "#729FCF",
            "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234",
            "brightPurple": "#AD7FA8",
            "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC",
            "brightYellow": "#FCE94F",
            "cursorColor": "#000000",
            "cyan": "#06989A",
            "foreground": "#555753",
            "green": "#4E9A06",
            "name": "Tango Light",
            "purple": "#75507B",
            "red": "#CC0000",
            "selectionBackground": "#FFFFFF",
            "white": "#D3D7CF",
            "yellow": "#C4A000"
        },
        {
            "background": "#000000",
            "black": "#000000",
            "blue": "#000080",
            "brightBlack": "#808080",
            "brightBlue": "#0000FF",
            "brightCyan": "#00FFFF",
            "brightGreen": "#00FF00",
            "brightPurple": "#FF00FF",
            "brightRed": "#FF0000",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFFF00",
            "cursorColor": "#FFFFFF",
            "cyan": "#008080",
            "foreground": "#C0C0C0",
            "green": "#008000",
            "name": "Vintage",
            "purple": "#800080",
            "red": "#800000",
            "selectionBackground": "#FFFFFF",
            "white": "#C0C0C0",
            "yellow": "#808000"
        },
        {
            "background": "#111927",
            "black": "#000000",
            "blue": "#004CFF",
            "brightBlack": "#666666",
            "brightBlue": "#5CB2FF",
            "brightCyan": "#5CECC6",
            "brightGreen": "#C5F467",
            "brightPurple": "#AE81FF",
            "brightRed": "#FF8484",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFCC5C",
            "cursorColor": "#FFFFFF",
            "cyan": "#2EE7B6",
            "foreground": "#D4D4D4",
            "green": "#9FEF00",
            "name": "xcad_hackthebox",
            "purple": "#BC3FBC",
            "red": "#FF3E3E",
            "selectionBackground": "#FFFFFF",
            "white": "#FFFFFF",
            "yellow": "#FFAF00"
        },
        {
            "background": "#1A1A1A",
            "black": "#121212",
            "blue": "#2B4FFF",
            "brightBlack": "#2F2F2F",
            "brightBlue": "#5C78FF",
            "brightCyan": "#5AC8FF",
            "brightGreen": "#905AFF",
            "brightPurple": "#5EA2FF",
            "brightRed": "#BA5AFF",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#685AFF",
            "cursorColor": "#FFFFFF",
            "cyan": "#28B9FF",
            "foreground": "#F1F1F1",
            "green": "#7129FF",
            "name": "xcad_tdl",
            "purple": "#2883FF",
            "red": "#A52AFF",
            "selectionBackground": "#FFFFFF",
            "white": "#F1F1F1",
            "yellow": "#3D2AFF"
        },
        {
            "background": "#0F0F0F",
            "black": "#000000",
            "blue": "#2878FF",
            "brightBlack": "#2F2F2F",
            "brightBlue": "#5E99FF",
            "brightCyan": "#5AD6FF",
            "brightGreen": "#FFB15A",
            "brightPurple": "#935CFF",
            "brightRed": "#FF755A",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FFD25A",
            "cursorColor": "#FFFFFF",
            "cyan": "#28C8FF",
            "foreground": "#F1F1F1",
            "green": "#FF9A28",
            "name": "xcad_tdl_colorful",
            "purple": "#732BFF",
            "red": "#FF4C27",
            "selectionBackground": "#FFFFFF",
            "white": "#F1F1F1",
            "yellow": "#FFC72A"
        },
        {
            "background": "#0F0F0F",
            "black": "#000000",
            "blue": "#184AE8",
            "brightBlack": "#5F5F5F",
            "brightBlue": "#4771F5",
            "brightCyan": "#31C1FF",
            "brightGreen": "#FFD631",
            "brightPurple": "#7631FF",
            "brightRed": "#FF3190",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#FF9731",
            "cursorColor": "#FFFFFF",
            "cyan": "#008DCB",
            "foreground": "#D9D9D9",
            "green": "#CBA300",
            "name": "xcad_tdl_old",
            "purple": "#4300CB",
            "red": "#CB005F",
            "selectionBackground": "#FFFFFF",
            "white": "#CFCFCF",
            "yellow": "#CB6600"
        },
        {
            "background": "#282C34",
            "black": "#000000",
            "blue": "#007ACC",
            "brightBlack": "#75715E",
            "brightBlue": "#11A8CD",
            "brightCyan": "#11A8CD",
            "brightGreen": "#0DBC79",
            "brightPurple": "#AE81FF",
            "brightRed": "#DD6B65",
            "brightWhite": "#F8F8F2",
            "brightYellow": "#E6DB74",
            "cursorColor": "#FFFFFF",
            "cyan": "#11A8CD",
            "foreground": "#D4D4D4",
            "green": "#0DBC79",
            "name": "xcad_vscode",
            "purple": "#BC3FBC",
            "red": "#F4423A",
            "selectionBackground": "#FFFFFF",
            "white": "#F8F8F2",
            "yellow": "#E5E510"
        }
    ],
    "showTabsInTitlebar": true,
    "tabSwitcherMode": "inOrder",
    "useAcrylicInTabRow": true
}
'@

    # Build exact startingDirectory UNC paths with the resolved WSL username.
    # Verbatim from ChristianLempa/dotfiles-win settings.json:
    #   Ubuntu  → \\wsl$\Ubuntu-20.04\home\<user>     (legacy wsl$ share)
    #   Kali    → \\wsl.localhost\kali-linux\home\<user>
    #   Arch    → \\wsl.localhost\Arch\home\<user>
    $ubuntuDir = '\\\\wsl$\\Ubuntu-20.04\\home\\' + $resolvedWslUser
    $kaliDir   = '\\\\wsl.localhost\\kali-linux\\home\\' + $resolvedWslUser
    $archDir2  = '\\\\wsl.localhost\\Arch\\home\\' + $resolvedWslUser

    $wtSettings = $wtSettings.Replace('UBUNTU_DIR_PLACEHOLDER', $ubuntuDir)
    $wtSettings = $wtSettings.Replace('KALI_DIR_PLACEHOLDER',   $kaliDir)
    $wtSettings = $wtSettings.Replace('ARCH_DIR_PLACEHOLDER',   $archDir2)

    foreach ($wtPath in $wtPaths) {
        $wtDir = Split-Path $wtPath
        if (Test-Path $wtDir) {
            Backup-File $wtPath
            $wtSettings | Set-Content -Path $wtPath -Encoding UTF8
            Write-OK "Windows Terminal settings written: $wtPath"
        } else {
            Write-Skip "Windows Terminal not found at: $wtDir"
        }
    }
} else {
    Write-Skip "Windows Terminal settings skipped (-SkipTerminalSettings)"
}

# ── 6. Starship config ────────────────────────────────────────────────────────

if (-not $SkipStarship) {
    Write-Step "Writing Starship prompt config (~/.starship/starship.toml)"

    $starshipDir  = "$HOME\.starship"
    $starshipToml = "$starshipDir\starship.toml"

    if (-not (Test-Path $starshipDir)) {
        New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null
    }

    Backup-File $starshipToml

    # xcad-flavored Starship config matching Christian Lempa's style
    $starshipConfig = @'
# ~/.starship/starship.toml  —  Christian Lempa / xcad theme

format = """
[░▒▓](#a3aed2)\
[  ](bg:#a3aed2 fg:#090c0c)\
[](bg:#769ff0 fg:#a3aed2)\
$directory\
[](fg:#769ff0 bg:#394260)\
$git_branch\
$git_status\
[](fg:#394260 bg:#212736)\
$nodejs\
$rust\
$golang\
$php\
[](fg:#212736 bg:#1d2230)\
$time\
[ ](bg:#1d2230)\
\n$character"""

[directory]
style = "fg:#e3e5e5 bg:#769ff0"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music"     = " "
"Pictures"  = " "

[git_branch]
symbol = ""
style  = "bg:#394260"
format = '[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)'

[git_status]
style  = "bg:#394260"
format = '[[($all_status$ahead_behind )](fg:#769ff0 bg:#394260)]($style)'

[nodejs]
symbol = ""
style  = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[rust]
symbol = ""
style  = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[golang]
symbol = ""
style  = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[php]
symbol = ""
style  = "bg:#212736"
format = '[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)'

[time]
disabled    = false
time_format = "%R"
style       = "bg:#1d2230"
format      = '[[  $time ](fg:#a0a9cb bg:#1d2230)]($style)'
'@

    $starshipConfig | Set-Content -Path $starshipToml -Encoding UTF8
    Write-OK "Starship config written: $starshipToml"
} else {
    Write-Skip "Starship config skipped (-SkipStarship)"
}

# ── 7. PowerShell Profile ─────────────────────────────────────────────────────

if (-not $SkipProfile) {
    Write-Step "Writing PowerShell profile ($PROFILE)"

    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    Backup-File $PROFILE

    $psProfile = @'
# ============================================================
# Microsoft.PowerShell_profile.ps1
# Christian Lempa dotfiles-win
# https://github.com/ChristianLempa/dotfiles-win
# ============================================================

# ── Aliases ───────────────────────────────────────────────────
New-Alias k kubectl

# Remove built-in 'h' alias if it exists, then alias helm
if (Get-Alias h -ErrorAction SilentlyContinue) { Remove-Alias h -Force }
New-Alias h helm

New-Alias g goto

# ── goto shortcut ─────────────────────────────────────────────
function goto {
    param (
        [string]$location
    )
    Switch ($location) {
        "pr" { Set-Location -Path "$HOME/projects" }
        "bp" { Set-Location -Path "$HOME/projects/boilerplates" }
        "cs" { Set-Location -Path "$HOME/projects/cheat-sheets" }
        default { Write-Host "Invalid location. Valid options: pr, bp, cs" -ForegroundColor Yellow }
    }
}

# ── Kubernetes ────────────────────────────────────────────────
$ENV:KUBECONFIG = "$HOME\.kube\prod-k8s-clcreative-kubeconfig.yaml;$HOME\.kube\civo-k8s_test_1-kubeconfig;$HOME\.kube\k8s_test_1.yml"

function kn {
    param ([string]$namespace)
    if ($namespace -in "default", "d") {
        kubectl config set-context --current --namespace=default
    } else {
        kubectl config set-context --current --namespace=$namespace
    }
}

# ── Starship prompt ───────────────────────────────────────────
$ENV:STARSHIP_CONFIG  = "$HOME\.starship\starship.toml"
$ENV:STARSHIP_DISTRO  = "者 xcad"
Invoke-Expression (&starship init powershell)

# ── Terminal-Icons (Nerd Font glyphs in ls output) ────────────
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons
}

# ── PSReadLine (history-based autocomplete, zsh-style menu) ───
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# ── Datree tab completion  -*- shell-script -*- ───────────────

function __datree_debug {
    if ($env:BASH_COMP_DEBUG_FILE) {
        "$args" | Out-File -Append -FilePath "$env:BASH_COMP_DEBUG_FILE"
    }
}

filter __datree_escapeStringWithSpecialChars {
    $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}

Register-ArgumentCompleter -CommandName 'datree' -ScriptBlock {
    param(
        $WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    $Command = $CommandAst.CommandElements
    $Command = "$Command"

    __datree_debug ""
    __datree_debug "========= starting completion logic =========="
    __datree_debug "WordToComplete: $WordToComplete Command: $Command CursorPosition: $CursorPosition"

    if ($Command.Length -gt $CursorPosition) {
        $Command = $Command.Substring(0, $CursorPosition)
    }
    __datree_debug "Truncated command: $Command"

    $ShellCompDirectiveError         = 1
    $ShellCompDirectiveNoSpace       = 2
    $ShellCompDirectiveNoFileComp    = 4
    $ShellCompDirectiveFilterFileExt = 8
    $ShellCompDirectiveFilterDirs    = 16

    $Program, $Arguments = $Command.Split(" ", 2)
    $RequestComp = "$Program __complete $Arguments"
    __datree_debug "RequestComp: $RequestComp"

    if ($WordToComplete -ne "") {
        $WordToComplete = $Arguments.Split(" ")[-1]
    }
    __datree_debug "New WordToComplete: $WordToComplete"

    $IsEqualFlag = ($WordToComplete -Like "--*=*")
    if ($IsEqualFlag) {
        __datree_debug "Completing equal sign flag"
        $Flag, $WordToComplete = $WordToComplete.Split("=", 2)
    }

    if ($WordToComplete -eq "" -And (-Not $IsEqualFlag)) {
        __datree_debug "Adding extra empty parameter"
        $RequestComp = "$RequestComp" + ' `"`"'
    }

    __datree_debug "Calling $RequestComp"
    Invoke-Expression -OutVariable out "$RequestComp" 2>&1 | Out-Null

    [int]$Directive = $Out[-1].TrimStart(':')
    if ($Directive -eq "") { $Directive = 0 }
    __datree_debug "The completion directive is: $Directive"

    $Out = $Out | Where-Object { $_ -ne $Out[-1] }
    __datree_debug "The completions are: $Out"

    if (($Directive -band $ShellCompDirectiveError) -ne 0) {
        __datree_debug "Received error from custom completion go code"
        return
    }

    $Longest = 0
    $Values = $Out | ForEach-Object {
        $Name, $Description = $_.Split("`t", 2)
        __datree_debug "Name: $Name Description: $Description"
        if ($Longest -lt $Name.Length) { $Longest = $Name.Length }
        if (-Not $Description) { $Description = " " }
        @{ Name = "$Name"; Description = "$Description" }
    }

    $Space = " "
    if (($Directive -band $ShellCompDirectiveNoSpace) -ne 0) {
        __datree_debug "ShellCompDirectiveNoSpace is called"
        $Space = ""
    }

    if (($Directive -band $ShellCompDirectiveNoFileComp) -ne 0) {
        __datree_debug "ShellCompDirectiveNoFileComp is called"
        if ($Values.Length -eq 0) { ""; return }
    }

    if ((($Directive -band $ShellCompDirectiveFilterFileExt) -ne 0) -or
        (($Directive -band $ShellCompDirectiveFilterDirs) -ne 0)) {
        __datree_debug "ShellCompDirectiveFilterFileExt ShellCompDirectiveFilterDirs are not supported"
        return
    }

    $Values = $Values | Where-Object {
        $_.Name -like "$WordToComplete*"
        if ($IsEqualFlag) {
            __datree_debug "Join the equal sign flag back to the completion value"
            $_.Name = $Flag + "=" + $_.Name
        }
    }

    $Mode = (Get-PSReadLineKeyHandler | Where-Object { $_.Key -eq "Tab" }).Function
    __datree_debug "Mode: $Mode"

    $Values | ForEach-Object {
        $comp = $_
        switch ($Mode) {
            "Complete" {
                if ($Values.Length -eq 1) {
                    __datree_debug "Only one completion left"
                    [System.Management.Automation.CompletionResult]::new(
                        $($comp.Name | __datree_escapeStringWithSpecialChars) + $Space,
                        "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
                } else {
                    while ($comp.Name.Length -lt $Longest) { $comp.Name = $comp.Name + " " }
                    if ($($comp.Description) -eq " ") { $Description = "" }
                    else { $Description = "  ($($comp.Description))" }
                    [System.Management.Automation.CompletionResult]::new(
                        "$($comp.Name)$Description",
                        "$($comp.Name)$Description", 'ParameterValue', "$($comp.Description)")
                }
            }
            "MenuComplete" {
                [System.Management.Automation.CompletionResult]::new(
                    $($comp.Name | __datree_escapeStringWithSpecialChars) + $Space,
                    "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
            }
            Default {
                [System.Management.Automation.CompletionResult]::new(
                    $($comp.Name | __datree_escapeStringWithSpecialChars),
                    "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
            }
        }
    }
}
'@

    $psProfile | Set-Content -Path $PROFILE -Encoding UTF8
    Write-OK "PowerShell profile written: $PROFILE"

    # Install Terminal-Icons PS module if missing
    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "    Installing Terminal-Icons module from PSGallery..." -ForegroundColor Yellow
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser
        Write-OK "Terminal-Icons installed"
    } else {
        Write-Skip "Terminal-Icons already installed"
    }
} else {
    Write-Skip "PowerShell profile skipped (-SkipProfile)"
}

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host "`n$(('=' * 66))" -ForegroundColor Cyan
Write-Host "  Christian Lempa dotfiles-win installation complete!" -ForegroundColor Green
Write-Host "$(('=' * 66))`n" -ForegroundColor Cyan
Write-Host @"
  What was installed / configured
  ──────────────────────────────────────────────────────────────
  Fonts        Hack Nerd Font + Hack Nerd Font Mono
  CLI tools    starship · git · kubectl · helm · datree
  Icons        git clone github.com/smothermonethan/icon
               → $env:USERPROFILE\WindowsTerminalIcons\
  WSL distros  Ubuntu-20.04  → \\wsl`$\Ubuntu-20.04\home\$resolvedWslUser
               kali-linux    → \\wsl.localhost\kali-linux\home\$resolvedWslUser
               Arch          → \\wsl.localhost\Arch\home\$resolvedWslUser
  Terminal     defaultProfile: Ubuntu Linux
               colour scheme: xcad_tdl (+ hackthebox, colorful, vscode variants)
               font: Hack Nerd Font 14pt · opacity 95 · 5 profiles w/ tab colours
  Starship     xcad theme prompt
  PS profile   aliases k/h/g · goto · kn · Terminal-Icons
               PSReadLine history autocomplete · datree tab completion

  Next steps
  ──────────────────────────────────────────────────────────────
  1. Restart Windows Terminal — xcad_tdl theme + icons8 tab icons take effect.
  2. Verify font: Terminal > Settings > Defaults > Font = "Hack Nerd Font".
  3. First WSL launch — create your UNIX user:
       wsl -d Ubuntu-20.04      →  username should be: $resolvedWslUser
       wsl -d kali-linux        →  username should be: $resolvedWslUser
       %USERPROFILE%\WSL\Arch\Arch.exe  →  follow Arch setup, then:
         useradd -m -G wheel $resolvedWslUser && passwd $resolvedWslUser
  4. Kali hackbox tooling:   sudo apt update && sudo apt install -y kali-linux-default
  5. If your Linux username differs, re-run:
       .\Install-Dotfiles.ps1 -WslUsername "yourname" -SkipWsl -SkipFonts -SkipPackages
  6. Pull latest icons any time:   git -C "$env:USERPROFILE\WindowsTerminalIcons" pull
  7. Reload profile:   . `$PROFILE
"@ -ForegroundColor White
