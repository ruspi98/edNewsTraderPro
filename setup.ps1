# ====================================================================
# edNewsTraderPro - Automated Setup & Dependency Doctor
# Copyright (c) 2026 edNewsTraderPro
# ====================================================================

param(
    [switch]$CheckOnly,
    [switch]$AutoInstall,
    [switch]$DeployOnly,
    [switch]$CompileOnly,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectRoot = $PSScriptRoot
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Location).Path
}

# --------------------------------------------------------------------
# Formatting & Output Helpers
# --------------------------------------------------------------------
function Write-Header {
    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "       edNewsTraderPro - Setup & Dependency Doctor (v1.0)           " -ForegroundColor Yellow
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host " Project Directory: $ProjectRoot" -ForegroundColor Gray
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n[>>] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!]  $Message" -ForegroundColor Yellow
}

function Write-Failure {
    param([string]$Message)
    Write-Host "  [X]  $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "       $Message" -ForegroundColor Gray
}

# --------------------------------------------------------------------
# Download Helper (Curl or PowerShell WebRequest)
# --------------------------------------------------------------------
function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$DisplayName
    )
    Write-Host "  [-] Mengunduh $DisplayName..." -ForegroundColor Yellow
    Write-Info "URL: $Url"
    Write-Info "Tujuan: $Destination"

    $curlCmd = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curlCmd) {
        & curl.exe -L --progress-bar -o "$Destination" "$Url"
        if ($LASTEXITCODE -eq 0 -and (Test-Path "$Destination")) {
            Write-Success "Berhasil mengunduh $DisplayName."
            return $true
        }
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        if (Test-Path "$Destination") {
            Write-Success "Berhasil mengunduh $DisplayName."
            return $true
        }
    }
    catch {
        Write-Failure "Gagal mengunduh $DisplayName : $_"
        return $false
    }
    return $false
}

# --------------------------------------------------------------------
# STEP 1: Deteksi MetaTrader 5 (MT5 & MetaEditor)
# --------------------------------------------------------------------
function Check-MT5 {
    Write-Step "Mengecek Instalasi MetaTrader 5 (MT5) & MetaEditor..."
    
    $candidates = @()
    $appDataTerminal = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    
    # 1. Cari dari origin.txt pada folder AppData Terminal
    if (Test-Path $appDataTerminal) {
        $originFiles = Get-ChildItem -Path "$appDataTerminal\*\origin.txt" -ErrorAction SilentlyContinue
        foreach ($orig in $originFiles) {
            $originPath = (Get-Content $orig.FullName -ErrorAction SilentlyContinue).Trim()
            if ($originPath -and (Test-Path $originPath)) {
                $candidates += $originPath
            }
        }
    }

    # 2. Cari dari direktori umum Program Files
    $commonDirs = @(
        "C:\Program Files\MetaTrader 5",
        "C:\Program Files\MetaTrader 5 EXNESS",
        "C:\Program Files\MetaTrader 5 EXNESS - Copy",
        "C:\Program Files\FBS MetaTrader 5",
        "C:\Program Files (x86)\MetaTrader 5"
    )
    foreach ($d in $commonDirs) {
        if (Test-Path $d) {
            $candidates += $d
        }
    }

    # 3. Cari dari Registry jika belum ketemu
    if ($candidates.Count -eq 0) {
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        foreach ($rp in $regPaths) {
            $items = Get-ItemProperty $rp -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.DisplayName -like "*MetaTrader 5*" -and $item.InstallLocation) {
                    $candidates += $item.InstallLocation
                }
            }
        }
    }

    # Hilangkan duplikat
    $uniqueCandidates = $candidates | Select-Object -Unique

    $validMT5 = @()
    foreach ($dir in $uniqueCandidates) {
        $termExe = Join-Path $dir "terminal64.exe"
        $editorExe = Join-Path $dir "metaeditor64.exe"
        if ((Test-Path $termExe) -and (Test-Path $editorExe)) {
            $validMT5 += [PSCustomObject]@{
                Directory   = $dir
                TerminalExe = $termExe
                EditorExe   = $editorExe
            }
        }
    }

    if ($validMT5.Count -gt 0) {
        Write-Success "MetaTrader 5 ditemukan ($($validMT5.Count) instalasi terdeteksi):"
        foreach ($mt in $validMT5) {
            Write-Info "- Folder: $($mt.Directory)"
            Write-Info "  Terminal  : $($mt.TerminalExe)"
            Write-Info "  MetaEditor: $($mt.EditorExe)"
        }
        return $validMT5
    }

    # Jika MT5 TIDAK ditemukan
    Write-Failure "MetaTrader 5 (terminal64.exe / metaeditor64.exe) TIDAK ditemukan di sistem!"
    
    if ($CheckOnly) {
        return $null
    }

    $shouldDownload = $false
    if ($AutoInstall) {
        $shouldDownload = $true
    } elseif (-not $NonInteractive) {
        Write-Host ""
        $reply = Read-Host "Apakah Anda ingin mendownload & menginstal MetaTrader 5 sekarang? [Y/N]"
        if ($reply -match "^[yY]") {
            $shouldDownload = $true
        }
    }

    if ($shouldDownload) {
        $mt5Url = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
        $tempInstaller = Join-Path $env:TEMP "mt5setup.exe"
        $downloadOk = Download-File -Url $mt5Url -Destination $tempInstaller -DisplayName "MetaTrader 5 Official Installer"
        if ($downloadOk) {
            Write-Host "  [-] Menjalankan installer MetaTrader 5..." -ForegroundColor Cyan
            Write-Info "Silakan ikuti instruksi pada jendela wizard instalasi MT5."
            Start-Process -FilePath $tempInstaller -Wait
            Write-Success "Instalasi selesai. Memindai ulang instalasi MT5..."
            return (Check-MT5)
        }
    }

    return $null
}

# --------------------------------------------------------------------
# STEP 2: Deteksi Python 3 & Dependensi
# --------------------------------------------------------------------
function Check-Python {
    Write-Step "Mengecek Instalasi Python 3..."
    
    $pythonCmd = Get-Command "python.exe" -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $pythonCmd = Get-Command "py.exe" -ErrorAction SilentlyContinue
    }

    if ($pythonCmd) {
        $pyVersion = (& $pythonCmd.Source --version 2>&1)
        Write-Success "Python terdeteksi: $pyVersion"
        Write-Info "Path: $($pythonCmd.Source)"
        return $pythonCmd.Source
    }

    # Cek lokasi instalasi umum Python jika belum masuk PATH
    $commonPyPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "C:\Python311\python.exe",
        "C:\Python312\python.exe"
    )
    foreach ($p in $commonPyPaths) {
        if (Test-Path $p) {
            $pyVersion = (& $p --version 2>&1)
            Write-Success "Python ditemukan (belum ada di PATH sistem): $pyVersion"
            Write-Info "Path: $p"
            return $p
        }
    }

    Write-Warn "Python 3 TIDAK terdeteksi di sistem!"
    Write-Info "(Python dibutuhkan untuk menjalankan script generator kalender: generate_calendar.py)"

    if ($CheckOnly) {
        return $null
    }

    $shouldDownloadPy = $false
    if ($AutoInstall) {
        $shouldDownloadPy = $true
    } elseif (-not $NonInteractive) {
        Write-Host ""
        $reply = Read-Host "Apakah Anda ingin mendownload & menginstal Python 3.11 sekarang? [Y/N]"
        if ($reply -match "^[yY]") {
            $shouldDownloadPy = $true
        }
    }

    if ($shouldDownloadPy) {
        $pyUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
        $tempPyInstaller = Join-Path $env:TEMP "python-3.11.9-amd64.exe"
        $downloadOk = Download-File -Url $pyUrl -Destination $tempPyInstaller -DisplayName "Python 3.11 Installer"
        if ($downloadOk) {
            Write-Host "  [-] Menjalankan installer Python (otomatis menambahkan ke PATH)..." -ForegroundColor Cyan
            Start-Process -FilePath $tempPyInstaller -ArgumentList "/passive PrependPath=1 Include_pip=1" -Wait
            Write-Success "Instalasi Python selesai."
            return (Check-Python)
        }
    }

    return $null
}

# --------------------------------------------------------------------
# STEP 3: Generate / Validasi Data Kalender Berita (CSV)
# --------------------------------------------------------------------
function Setup-Calendar {
    param([string]$PythonExe)
    Write-Step "Mengecek & Menyiapkan File Kalender Berita (CSV)..."

    $cal3Years = Join-Path $ProjectRoot "news_calendar_3years.csv"
    $calDefault = Join-Path $ProjectRoot "news_calendar.csv"
    $genScript = Join-Path $ProjectRoot "generate_calendar.py"

    $needGenerate = (-not (Test-Path $cal3Years))

    if ($needGenerate) {
        Write-Warn "File $cal3Years belum tersedia."
        if ($PythonExe) {
            Write-Host "  [-] Menjalankan $genScript menggunakan Python..." -ForegroundColor Cyan
            & $PythonExe $genScript
            if (Test-Path $cal3Years) {
                Write-Success "File kalender berita 3 tahun berhasil dibuat!"
            } else {
                Write-Failure "Gagal membuat $cal3Years."
            }
        } else {
            Write-Failure "Python tidak tersedia untuk menggenerate kalender berita."
        }
    } else {
        $lineCount = (Get-Content $cal3Years | Measure-Object -Line).Lines
        Write-Success "File kalender 3 tahun ditemukan: $cal3Years ($lineCount entri baris)."
    }

    if (Test-Path $calDefault) {
        Write-Success "File kalender default ditemukan: $calDefault"
    }
}

# --------------------------------------------------------------------
# STEP 4: Deploy Modul EA & Kalender ke Folder Data MT5
# --------------------------------------------------------------------
function Deploy-ToMT5 {
    Write-Step "Menyinkronkan File EA & Kalender ke Folder Data MT5..."

    $appDataTerminal = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path $appDataTerminal)) {
        Write-Failure "Folder AppData Terminal MetaQuotes tidak ditemukan: $appDataTerminal"
        return $null
    }

    # Cari semua folder instance MT5 di AppData
    $instances = Get-ChildItem -Path $appDataTerminal -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName "MQL5")) -and ($_.Name -notmatch "^(Common|Community|Help)$")
    }

    if ($instances.Count -eq 0) {
        Write-Warn "Tidak ditemukan folder data MQL5 aktif di $appDataTerminal"
        return $null
    }

    # 1. Selalu copy kalender ke Common\Files agar bisa diakses seluruh terminal via FILE_COMMON
    $commonFilesDir = Join-Path $appDataTerminal "Common\Files"
    if (-not (Test-Path $commonFilesDir)) {
        New-Item -ItemType Directory -Path $commonFilesDir -Force | Out-Null
    }
    
    $cal3Years = Join-Path $ProjectRoot "news_calendar_3years.csv"
    $calDefault = Join-Path $ProjectRoot "news_calendar.csv"

    if (Test-Path $cal3Years) {
        Copy-Item -Path $cal3Years -Destination $commonFilesDir -Force
        Write-Success "Disalin ke Terminal Common\Files: news_calendar_3years.csv"
    }
    if (Test-Path $calDefault) {
        Copy-Item -Path $calDefault -Destination $commonFilesDir -Force
        Write-Success "Disalin ke Terminal Common\Files: news_calendar.csv"
    }

    # 2. Deploy ke masing-masing folder MQL5
    $deployedFolders = @()
    foreach ($inst in $instances) {
        $mql5Dir = Join-Path $inst.FullName "MQL5"
        $expertsDir = Join-Path $mql5Dir "Experts\edNewsTraderPro"
        $filesDir = Join-Path $mql5Dir "Files"

        # Buat folder jika belum ada
        if (-not (Test-Path $expertsDir)) {
            New-Item -ItemType Directory -Path $expertsDir -Force | Out-Null
        }
        if (-not (Test-Path $filesDir)) {
            New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
        }

        # Salin file kalender ke MQL5\Files lokal terminal
        if (Test-Path $cal3Years) { Copy-Item -Path $cal3Years -Destination $filesDir -Force }
        if (Test-Path $calDefault) { Copy-Item -Path $calDefault -Destination $filesDir -Force }

        # Salin struktur folder edNewsTraderPro
        $foldersToCopy = @("Config", "Core", "Execution", "News", "Strategy", "Scripts", "reports")
        foreach ($f in $foldersToCopy) {
            $srcFolder = Join-Path $ProjectRoot $f
            if (Test-Path $srcFolder) {
                $dstFolder = Join-Path $expertsDir $f
                Copy-Item -Path $srcFolder -Destination $expertsDir -Recurse -Force
            }
        }

        # Salin file root modul
        $filesToCopy = @("edNewsTraderPro.mq5", "tester_EURUSD.ini", "news_calendar_3years.csv", "news_calendar.csv", "README.md")
        foreach ($file in $filesToCopy) {
            $srcFile = Join-Path $ProjectRoot $file
            if (Test-Path $srcFile) {
                Copy-Item -Path $srcFile -Destination $expertsDir -Force
            }
        }

        Write-Success "Tersinkronisasi ke: $expertsDir"
        $deployedFolders += $expertsDir
    }

    return $deployedFolders
}

# --------------------------------------------------------------------
# STEP 5: Kompilasi Otomatis Menggunakan MetaEditor64
# --------------------------------------------------------------------
function Compile-EA {
    param(
        $MT5List,
        $DeployedFolders
    )
    Write-Step "Mengompilasi edNewsTraderPro.mq5 Menggunakan MetaEditor..."

    if (-not $MT5List -or $MT5List.Count -eq 0) {
        Write-Failure "MetaEditor tidak ditemukan. Tidak dapat mengompilasi EA."
        return $false
    }

    $metaEditor = $MT5List[0].EditorExe
    $mainMq5 = Join-Path $ProjectRoot "edNewsTraderPro.mq5"
    $compileLog = Join-Path $ProjectRoot "compile.log"

    Write-Info "Compiler: $metaEditor"
    Write-Info "Source  : $mainMq5"

    # Hapus log lama jika ada
    if (Test-Path $compileLog) { Remove-Item $compileLog -Force }

    # Eksekusi MetaEditor dengan Start-Process -Wait
    $argsList = @(
        "/compile:`"$mainMq5`"",
        "/log:`"$compileLog`""
    )

    $proc = Start-Process -FilePath $metaEditor -ArgumentList $argsList -Wait -PassThru -WindowStyle Hidden
    
    # Tunggu beberapa saat agar file log ditulis sepenuhnya
    Start-Sleep -Milliseconds 800

    $isSuccess = $false
    if (Test-Path $compileLog) {
        # Format log MetaEditor sering berupa UTF-16LE
        $logContent = Get-Content -Path $compileLog -Encoding Unicode -ErrorAction SilentlyContinue
        if (-not $logContent) {
            $logContent = Get-Content -Path $compileLog -ErrorAction SilentlyContinue
        }

        $resultLine = $logContent | Where-Object { $_ -match "Result:" -or $_ -match "errors" }
        if ($resultLine) {
            Write-Info "$resultLine"
        }

        $hasZeroErrors = ($logContent | Where-Object { $_ -match "0 errors" })
        if ($hasZeroErrors -and (Test-Path (Join-Path $ProjectRoot "edNewsTraderPro.ex5"))) {
            Write-Success "Kompilasi BERHASIL! Binary siap pakai: edNewsTraderPro.ex5"
            $isSuccess = $true
        } else {
            Write-Failure "Kompilasi GAGAL atau terdapat error!"
            $errors = $logContent | Where-Object { $_ -match "error" }
            foreach ($e in $errors) {
                Write-Host "    $e" -ForegroundColor Red
            }
        }
    } else {
        # Jika file compile.log tidak tertulis di direktori proyek, cek ex5
        $ex5 = Join-Path $ProjectRoot "edNewsTraderPro.ex5"
        if (Test-Path $ex5) {
            Write-Success "Binary terdeteksi: $ex5"
            $isSuccess = $true
        } else {
            Write-Failure "Kompilasi gagal atau MetaEditor tidak menghasilkan log."
        }
    }

    # Salin binary ex5 ke folder deployed jika berhasil
    if ($isSuccess -and $DeployedFolders) {
        $ex5Src = Join-Path $ProjectRoot "edNewsTraderPro.ex5"
        foreach ($dFolder in $DeployedFolders) {
            Copy-Item -Path $ex5Src -Destination $dFolder -Force
            Write-Success "Binary disalin ke folder MT5: $dFolder\edNewsTraderPro.ex5"
        }
    }

    return $isSuccess
}

# --------------------------------------------------------------------
# MAIN EXECUTION FLOW
# --------------------------------------------------------------------
Write-Header

# 1. Cek MT5
$mt5List = Check-MT5

# 2. Cek Python
$pyExe = Check-Python

if ($CheckOnly) {
    Write-Step "Mode Pemeriksaan Selesai (-CheckOnly)."
    Write-Host "`nRingkasan Dependensi:" -ForegroundColor Cyan
    Write-Host "- MetaTrader 5: $(if ($mt5List) { 'TERSEDIA' } else { 'TIDAK DITEMUKAN' })"
    Write-Host "- Python 3    : $(if ($pyExe) { 'TERSEDIA' } else { 'TIDAK DITEMUKAN' })"
    return
}

# 3. Setup Kalender
Setup-Calendar -PythonExe $pyExe

# 4. Deploy File ke MT5 Data
$deployedFolders = Deploy-ToMT5

# 5. Kompilasi EA
$compileSuccess = Compile-EA -MT5List $mt5List -DeployedFolders $deployedFolders

# 6. Ringkasan & Menu Interaktif
Write-Host "`n====================================================================" -ForegroundColor Cyan
Write-Host "                     SETUP SELESAI / STATUS                         " -ForegroundColor Yellow
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host " [$(if ($mt5List) {'OK'} else {'X'})] MetaTrader 5 & MetaEditor Terpasang" -ForegroundColor $(if ($mt5List) {'Green'} else {'Red'})
Write-Host " [$(if ($pyExe) {'OK'} else {'!'})] Python 3 Terpasang & Siap Digunakan" -ForegroundColor $(if ($pyExe) {'Green'} else {'Yellow'})
Write-Host " [$(if (Test-Path "$ProjectRoot\news_calendar_3years.csv") {'OK'} else {'X'})] Database Berita Ekonomi (3 Years)" -ForegroundColor Green
Write-Host " [$(if ($deployedFolders) {'OK'} else {'X'})] Modul EA Tersinkronisasi ke Data MT5" -ForegroundColor $(if ($deployedFolders) {'Green'} else {'Red'})
Write-Host " [$(if ($compileSuccess) {'OK'} else {'X'})] Kompilasi EA (edNewsTraderPro.ex5)" -ForegroundColor $(if ($compileSuccess) {'Green'} else {'Red'})
Write-Host "====================================================================" -ForegroundColor Cyan

if (-not $NonInteractive -and $mt5List) {
    Write-Host "`nPILIHAN TINDAKAN SELANJUTNYA:" -ForegroundColor White
    Write-Host "  [1] Jalankan Backtest EURUSD di Strategy Tester (Otomatis)"
    Write-Host "  [2] Buka MetaTrader 5 Terminal"
    Write-Host "  [3] Buka Source Code di MetaEditor"
    Write-Host "  [4] Keluar"
    Write-Host ""
    $choice = Read-Host "Pilih nomor [1-4] (default: 4)"

    switch ($choice) {
        "1" {
            $term = $mt5List[0].TerminalExe
            $iniPath = Join-Path $ProjectRoot "tester_EURUSD.ini"
            Write-Host "`nMemulai Strategy Tester dengan file konfigurasi: $iniPath..." -ForegroundColor Cyan
            Start-Process -FilePath $term -ArgumentList "/config:`"$iniPath`""
        }
        "2" {
            $term = $mt5List[0].TerminalExe
            Write-Host "`nMembuka MetaTrader 5..." -ForegroundColor Cyan
            Start-Process -FilePath $term
        }
        "3" {
            $editor = $mt5List[0].EditorExe
            $mainMq5 = Join-Path $ProjectRoot "edNewsTraderPro.mq5"
            Write-Host "`nMembuka MetaEditor..." -ForegroundColor Cyan
            Start-Process -FilePath $editor -ArgumentList "`"$mainMq5`""
        }
        default {
            Write-Host "Selesai. Anda dapat menjalankan setup kapan saja dengan menjalankan setup.bat." -ForegroundColor Green
        }
    }
}
