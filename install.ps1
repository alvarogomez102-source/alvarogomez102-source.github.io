<#
  Radisson demo - one-command local installer/launcher for Windows 10/11.
  - Works WITHOUT admin rights (everything goes into %LOCALAPPDATA%\RadissonDemo).
  - Installs portable PHP + portable MariaDB (needed by procesar.php / mysqli).
  - Creates database radisson_db + table contacto, starts everything, opens the browser.
  - Fails gracefully (clear message, nothing half-broken) if a requirement can't be met.
  Stop the demo with Ctrl+C in this window.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # much faster downloads in PS 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# ---------------- settings ----------------
$RepoZip   = 'https://github.com/alvarogomez102-source/alvarogomez102-source.github.io/archive/refs/heads/main.zip'
$MariaVers = @('11.4.5', '10.11.11')          # tried in order (archive.mariadb.org)
$PhpSeries = '8.4'                            # falls back to newest available
$DbName    = 'radisson_db'
$WebPorts  = 8080..8090
$DbPorts   = 33061..33070                     # non-standard so it never clashes with another MySQL
$MinFreeGB = 1.5

$HereDir = $PSScriptRoot                      # empty when run through "irm | iex"

function Say($m)  { Write-Host "  $m" }
function Step($m) { Write-Host "`n>> $m" -ForegroundColor Cyan }

function Get-File($url, $dest) {
    for ($i = 1; $i -le 3; $i++) {
        try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -UserAgent 'Mozilla/5.0'; return }
        catch { if ($i -eq 3) { throw } Start-Sleep -Seconds 2 }
    }
}
function Expand-Zip($zip, $dest) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
}
function Test-PortFree([int]$p) {
    try { $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $p); $l.Start(); $l.Stop(); $true } catch { $false }
}
function Test-PortOpen([int]$p) {
    try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $p); $c.Close(); $true } catch { $false }
}
function Find-Bin($dir, [string[]]$names) {
    foreach ($n in $names) {
        $f = Get-ChildItem -Path $dir -Recurse -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}
# Runs a native exe without PS 5.1's stderr-as-error problem; returns the exit code.
function Invoke-Native($exe, $argString, $log, $stdinFile) {
    $p = @{ FilePath = $exe; Wait = $true; PassThru = $true; WindowStyle = 'Hidden'
            RedirectStandardOutput = $log; RedirectStandardError = "$log.err" }
    if ($argString) { $p.ArgumentList = $argString }
    if ($stdinFile) { $p.RedirectStandardInput = $stdinFile }
    (Start-Process @p).ExitCode
}
function Read-Log($log) {
    ((Get-Content $log, "$log.err" -ErrorAction SilentlyContinue) -join "`n").Trim()
}

function Start-RadissonDemo {
    $dbProc = $null; $dbAdmin = $null; $dbPort = 0
    try {
        Write-Host "`n=== Radisson demo - local installer ===" -ForegroundColor Green

        # ---------- 1. check requirements BEFORE installing anything ----------
        Step 'Checking requirements'
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
                   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Say ("Admin rights: " + $(if ($isAdmin) { 'yes' } else { 'no (not needed)' }))

        $arch = $env:PROCESSOR_ARCHITEW6432; if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
        if ($arch -eq 'x86') { throw "32-bit Windows is not supported (PHP/MariaDB x64 builds are required)." }
        if ($arch -eq 'ARM64') { Say 'ARM64 detected: x64 binaries will run through Windows emulation.' }

        $base = Join-Path $env:LOCALAPPDATA 'RadissonDemo'
        New-Item -ItemType Directory -Force -Path $base | Out-Null
        $drive = (Get-Item $base).PSDrive
        if ($drive.Free -and ($drive.Free / 1GB) -lt $MinFreeGB) {
            throw ("Not enough free disk space on $($drive.Name): (need ~$MinFreeGB GB, have {0:N1} GB)." -f ($drive.Free / 1GB))
        }
        Say 'Disk space: ok'

        # Visual C++ runtime (required by PHP 8 and MariaDB). Only installable with admin.
        $vc = (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") -and (Test-Path "$env:SystemRoot\System32\vcruntime140_1.dll")
        if ($vc) { Say 'Visual C++ runtime: present' }
        else {
            Say 'Visual C++ runtime: MISSING'
            if (-not $isAdmin) {
                throw ("The Microsoft Visual C++ 2015-2022 (x64) runtime is missing and installing it needs admin rights.`n" +
                       "  Ask an administrator to install it once (https://aka.ms/vs/17/release/vc_redist.x64.exe),`n" +
                       "  or re-run this command from an 'Run as administrator' PowerShell.")
            }
            Say 'Installing it (admin detected)...'
            $vcExe = Join-Path $env:TEMP 'vc_redist.x64.exe'
            Get-File 'https://aka.ms/vs/17/release/vc_redist.x64.exe' $vcExe
            $code = (Start-Process $vcExe -ArgumentList '/install /quiet /norestart' -Wait -PassThru).ExitCode
            if ($code -notin 0, 1638, 3010) { throw "VC++ runtime installer failed (exit code $code)." }
            Remove-Item $vcExe -Force -ErrorAction SilentlyContinue
        }

        # ---------- 2. locate / fetch the project ----------
        Step 'Preparing project files'
        if ($HereDir -and (Test-Path (Join-Path $HereDir 'index.html')) -and (Test-Path (Join-Path $HereDir 'procesar.php'))) {
            $site = $HereDir
            Say "Using project in place: $site"
        } else {
            $site = Join-Path $base 'site'
            if (-not (Test-Path (Join-Path $site 'index.html'))) {
                Say 'Downloading project from GitHub...'
                $dl = Join-Path $base 'downloads'; New-Item -ItemType Directory -Force -Path $dl | Out-Null
                Get-File $RepoZip "$dl\site.zip"
                Expand-Zip "$dl\site.zip" "$dl\site_x"
                $inner = Get-ChildItem "$dl\site_x" -Directory | Select-Object -First 1
                if (Test-Path $site) { Remove-Item $site -Recurse -Force }
                Move-Item $inner.FullName $site
                Remove-Item "$dl\site.zip", "$dl\site_x" -Recurse -Force -ErrorAction SilentlyContinue
            }
            Say "Project: $site  (delete this folder to re-download)"
        }

        # ---------- 3. portable PHP ----------
        $tools  = Join-Path $base 'tools'
        $phpDir = Join-Path $tools 'php'
        $dbDir  = Join-Path $tools 'mariadb'
        $dataDir = Join-Path $base 'data'
        $dl = Join-Path $base 'downloads'; New-Item -ItemType Directory -Force -Path $tools, $dl | Out-Null

        Step 'PHP'
        if (-not (Test-Path "$phpDir\php.exe")) {
            Say 'Resolving latest PHP build...'
            $rel = Invoke-RestMethod 'https://windows.php.net/downloads/releases/releases.json' -UserAgent 'Mozilla/5.0'
            $names = @($rel.PSObject.Properties.Name)
            $key = if ($names -contains $PhpSeries) { $PhpSeries } else { $names | Sort-Object { [version]("$_.0") } -Descending | Select-Object -First 1 }
            $entry = $rel.$key
            $bk = $entry.PSObject.Properties.Name | Where-Object { $_ -match '^nts-v[sc]\d+-x64$' } | Select-Object -First 1
            if (-not $bk) { throw 'Could not find a non-thread-safe x64 PHP build for Windows.' }
            $zipInfo = $entry.$bk.zip
            Say "Downloading PHP $($entry.version) ..."
            Get-File ('https://windows.php.net/downloads/releases/' + $zipInfo.path) "$dl\php.zip"
            if ($zipInfo.sha256) {
                if ((Get-FileHash "$dl\php.zip" -Algorithm SHA256).Hash -ne $zipInfo.sha256) { throw 'PHP download checksum mismatch.' }
            }
            Expand-Zip "$dl\php.zip" $phpDir
            Remove-Item "$dl\php.zip" -Force
        }
        $php = "$phpDir\php.exe"

        # ---------- 4. portable MariaDB ----------
        Step 'MariaDB (MySQL-compatible database)'
        $mysqld = Find-Bin $dbDir @('mariadbd.exe', 'mysqld.exe')
        if (-not $mysqld) {
            $ok = $false
            foreach ($v in $MariaVers) {
                try {
                    Say "Downloading MariaDB $v (~90 MB)..."
                    Get-File "https://archive.mariadb.org/mariadb-$v/winx64-packages/mariadb-$v-winx64.zip" "$dl\mariadb.zip"
                    $ok = $true; break
                } catch { Say "  not available: $v" }
            }
            if (-not $ok) { throw 'Could not download MariaDB (network/proxy blocking archive.mariadb.org?).' }
            Say 'Extracting (this takes a minute)...'
            Expand-Zip "$dl\mariadb.zip" "$tools\_mdb"
            $inner = Get-ChildItem "$tools\_mdb" -Directory | Select-Object -First 1
            if (Test-Path $dbDir) { Remove-Item $dbDir -Recurse -Force }
            Move-Item $inner.FullName $dbDir
            Remove-Item "$tools\_mdb", "$dl\mariadb.zip" -Recurse -Force -ErrorAction SilentlyContinue
            $mysqld = Find-Bin $dbDir @('mariadbd.exe', 'mysqld.exe')
        }
        $installDb = Find-Bin $dbDir @('mysql_install_db.exe', 'mariadb-install-db.exe')
        $client    = Find-Bin $dbDir @('mariadb.exe', 'mysql.exe')
        $dbAdmin   = Find-Bin $dbDir @('mariadb-admin.exe', 'mysqladmin.exe')
        if (-not ($mysqld -and $installDb -and $client)) { throw 'MariaDB package is missing expected executables.' }

        # Sanity check: can these binaries actually run here? (catches AV / AppLocker / missing DLLs)
        $log = Join-Path $base 'check.log'
        foreach ($exe in @($php, $mysqld)) {
            try { $c = Invoke-Native $exe '--version' $log $null } catch { $c = -1 }
            if ($c -ne 0) {
                throw ("'$([IO.Path]::GetFileName($exe))' cannot run on this machine (exit $c).`n" +
                       "  Likely causes: antivirus/AppLocker blocking %LOCALAPPDATA%, or a missing runtime.`n  Details: " + (Read-Log $log))
            }
        }

        # ---------- 5. configure PHP (mysqli + DB port) ----------
        Step 'Configuring'
        $dbPort  = $DbPorts  | Where-Object { Test-PortFree $_ } | Select-Object -First 1
        $webPort = $WebPorts | Where-Object { Test-PortFree $_ } | Select-Object -First 1
        if (-not $dbPort)  { throw "No free database port in $($DbPorts[0])-$($DbPorts[-1])." }
        if (-not $webPort) { throw "No free web port in $($WebPorts[0])-$($WebPorts[-1])." }

        $ini = Get-Content "$phpDir\php.ini-development" -Raw
        $ini = $ini -replace '(?m)^;\s*extension_dir\s*=\s*"ext"', 'extension_dir = "ext"'
        foreach ($e in 'mysqli', 'mbstring', 'openssl') { $ini = $ini -replace "(?m)^;\s*extension=$e\s*$", "extension=$e" }
        $ini = $ini -replace '(?m)^mysqli\.default_port\s*=.*$', "mysqli.default_port = $dbPort"
        [IO.File]::WriteAllText("$phpDir\php.ini", $ini, (New-Object Text.UTF8Encoding($false)))
        if (-not (& $php -m | Select-String -SimpleMatch 'mysqli')) { throw 'PHP mysqli extension failed to load.' }
        Say "PHP ready (mysqli enabled, DB port $dbPort)"

        # ---------- 6. initialise + start database ----------
        # kill a stale instance of OUR mariadb left by a crashed previous run
        Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($dbDir, 'OrdinalIgnoreCase') } |
            Stop-Process -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path "$dataDir\mysql")) {
            Say 'Initialising database files...'
            if (Test-Path $dataDir) { Remove-Item $dataDir -Recurse -Force }
            $c = Invoke-Native $installDb "--datadir=`"$dataDir`"" $log $null
            if ($c -ne 0) { throw "Database initialisation failed:`n" + (Read-Log $log) }
        }

        Say "Starting database on 127.0.0.1:$dbPort ..."
        $dbLog = Join-Path $base 'mariadb.log'
        $dbProc = Start-Process -FilePath $mysqld -PassThru -WindowStyle Hidden `
            -ArgumentList "--datadir=`"$dataDir`" --port=$dbPort --bind-address=127.0.0.1 --skip-name-resolve --console" `
            -RedirectStandardOutput $dbLog -RedirectStandardError "$dbLog.err"
        $ready = $false
        for ($i = 0; $i -lt 60; $i++) {
            if ($dbProc.HasExited) { throw "Database exited on start-up:`n" + (Read-Log $dbLog) }
            if (Test-PortOpen $dbPort) { $ready = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) { throw 'Database did not become ready within 30 s.' }

        # schema inferred from procesar.php (safe to run repeatedly)
        $sqlFile = Join-Path $base 'schema.sql'
        @"
CREATE DATABASE IF NOT EXISTS $DbName CHARACTER SET utf8mb4;
CREATE TABLE IF NOT EXISTS $DbName.contacto (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100), apellidos VARCHAR(150), email VARCHAR(150),
  telefono VARCHAR(30), asunto VARCHAR(200), mensaje TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4;
"@ | Set-Content -Path $sqlFile -Encoding ASCII
        $c = Invoke-Native $client "-h 127.0.0.1 -P $dbPort -u root --protocol=tcp" $log $sqlFile
        if ($c -ne 0) { throw "Could not create database/table:`n" + (Read-Log $log) }
        Say "Database '$DbName' + table 'contacto' ready"

        # ---------- 7. run ----------
        $url = "http://127.0.0.1:$webPort/"
        Write-Host "`n=== Running: $url   (press Ctrl+C to stop) ===" -ForegroundColor Green
        Start-Process $url
        & $php -S "127.0.0.1:$webPort" -t $site
        return $true
    }
    catch {
        Write-Host "`nINSTALL FAILED - nothing was changed outside %LOCALAPPDATA%\RadissonDemo" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  (Logs: $env:LOCALAPPDATA\RadissonDemo)" -ForegroundColor DarkGray
        return $false
    }
    finally {
        if ($dbProc -and -not $dbProc.HasExited) {
            Write-Host "`nStopping database..."
            if ($dbAdmin) { try { Invoke-Native $dbAdmin "-h 127.0.0.1 -P $dbPort -u root shutdown" (Join-Path $env:TEMP 'rd_stop.log') $null | Out-Null } catch {} }
            if (-not $dbProc.WaitForExit(15000)) { Stop-Process -Id $dbProc.Id -Force -ErrorAction SilentlyContinue }
        }
    }
}

$ok = Start-RadissonDemo
# only set an exit code when run as a file (never kill the user's shell under "irm | iex")
if ($MyInvocation.MyCommand.Path -and -not $ok) { exit 1 }
