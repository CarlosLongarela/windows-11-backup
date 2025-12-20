param (
    [string]$backupPath = "P:\BackupWindows11"
)

# Comprobar permisos de Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script necesita ejecutarse como Administrador para realizar backups completos (Drivers, WiFi, etc)."
    Write-Warning "Por favor, reinicia el script con permisos elevados."
    exit
}

# Comprobar si existe la carpeta base de backup
if (-not (Test-Path -Path $backupPath)) {
    $response = Read-Host "¿La carpeta de backup '$backupPath' no existe. ¿Desea crearla? (S/N)"
    if ($response -eq 'S') {
        New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
        Write-Output "Carpeta creada: $backupPath"
    }
    elseif ($response -eq 'N') {
        Write-Warning "Operación cancelada por el usuario."
        exit
    }
    else {
        Write-Warning "Respuesta no válida. Operación cancelada."
        exit
    }
}

$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupPathDate = "$backupPath\$date"
New-Item -ItemType Directory -Force -Path $backupPathDate | Out-Null

# Iniciar Log
$logFile = "$backupPathDate\backup_log.txt"
Start-Transcript -Path $logFile -Append

Write-Output "Iniciando backup en: $backupPathDate"

# 1. Exportar lista de programas instalados con WinGet
Write-Output "Exportando lista de programas instalados con WinGet..."
$wingetLog = "$backupPathDate\winget_export.log"
winget export -o "$backupPathDate\winget_installed.json" 2>&1 | Out-File -Encoding utf8 $wingetLog
Select-String -Path $wingetLog -Pattern "El paquete instalado no está disponible" | Select-Object -ExpandProperty Line | Out-File -Encoding utf8 "$backupPathDate\paquetes_no_disponibles.txt"

# 2. Exportar lista completa de programas del sistema (32 y 64 bits)
Write-Output "Exportando lista de programas completos del sistema..."

$apps64 = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* `
| Select-Object DisplayName, DisplayVersion, Publisher, InstallDate

$apps32 = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
| Select-Object DisplayName, DisplayVersion, Publisher, InstallDate

$apps = $apps64 + $apps32 | Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne "" }

if ($apps.Count -gt 0) {
    $apps | Sort-Object DisplayName | Format-Table -AutoSize |
    Out-String | Out-File -Encoding utf8 "$backupPathDate\installed_apps.txt"
}
else {
    "No se encontraron programas instalados." | Out-File -Encoding utf8 "$backupPathDate\installed_apps.txt"
}

# 3. Exportar apps instaladas desde Microsoft Store
Write-Output "Exportando lista de apps de Microsoft Store..."
Get-AppxPackage | Select-Object Name, PackageFullName |
Out-File -Encoding utf8 "$backupPathDate\store_apps.txt"

# 4. Backup configuración de VS Code si existe
$vscodeConfigPath = "$env:APPDATA\Code\User"
if (Test-Path $vscodeConfigPath) {
    Write-Output "Guardando configuración de VS Code..."
    Copy-Item $vscodeConfigPath -Destination "$backupPathDate\VSCodeConfig" -Recurse -Force
}

# 5. Exportar distros de WSL2 (Auto-detección)
Write-Output "Detectando y exportando distros de WSL2..."

# Obtener lista limpia de distros
$wslList = wsl --list --quiet | Where-Object { $_ -ne "" -and $_ -ne $null } | ForEach-Object { $_.Trim() -replace "`0", "" }

if ($wslList) {
    $wslList | Out-File -Encoding utf8 "$backupPathDate\wsl_distros_list.txt"

    foreach ($distro in $wslList) {
        $distroTrim = $distro.Trim()
        if ($distroTrim -eq "") { continue }

        # Sanear nombre para usarlo en carpeta
        $safeDistroName = $distroTrim -replace '[^a-zA-Z0-9_-]', '_'

        $distroBackupPath = "$backupPathDate\WSL\$safeDistroName"
        New-Item -ItemType Directory -Path $distroBackupPath -Force | Out-Null

        # 5.1 Exportar la distro como .tar
        $tarPath = "$distroBackupPath\$safeDistroName-backup.tar"
        Write-Output "Exportando $distroTrim a $tarPath..."
        try {
            wsl --export $distroTrim $tarPath
        }
        catch {
            Write-Warning "❌ Error al exportar $distroTrim"
        }

        # 5.2 Backup de /home dentro de la distro usando WSL (sin rutas UNC)
        $homeTarPath = "$distroBackupPath\home_backup.tar"
        Write-Output "Exportando /home de $distroTrim como $homeTarPath..."

        # Usamos cmd.exe para la redirección binaria directa
        $cmdArgs = "/c wsl -d $distroTrim tar -cf - -C /home . > ""$homeTarPath"""
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs -Wait -NoNewWindow -PassThru

        # El código de salida 1 en tar suele ser "archivos cambiaron mientras se leían", lo cual es común en /home
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 1) {
            Write-Output "✓ Copia de /home completada en $homeTarPath"
        }
        else {
            Write-Warning "❌ No se pudo exportar el /home de $distroTrim. Código de salida: $($process.ExitCode)"
        }
    }
}
else {
    Write-Warning "No se detectaron distribuciones WSL instaladas."
}

# 6. Backup de Drivers (Requiere Admin)
Write-Output "Exportando Drivers de terceros..."
$driverPath = "$backupPathDate\Drivers"
New-Item -ItemType Directory -Force -Path $driverPath | Out-Null
try {
    # Usamos dism.exe directamente para evitar errores de clases COM/NET en algunas versiones de PS
    $dismArgs = "/online /export-driver /destination:""$driverPath"""
    $dismProcess = Start-Process -FilePath "dism.exe" -ArgumentList $dismArgs -Wait -NoNewWindow -PassThru

    if ($dismProcess.ExitCode -eq 0) {
        Write-Output "✓ Drivers exportados correctamente."
    }
    else {
        throw "DISM devolvió código de error $($dismProcess.ExitCode)"
    }
}
catch {
    Write-Warning "❌ Error al exportar drivers: $_"
}

# 7. Backup de Perfiles WiFi (Requiere Admin para ver claves, aunque exportar perfiles suele ser libre, mejor prevenir)
Write-Output "Exportando perfiles WiFi..."
$wifiPath = "$backupPathDate\WiFi"
New-Item -ItemType Directory -Force -Path $wifiPath | Out-Null
try {
    netsh wlan export profile folder="$wifiPath" key=clear | Out-Null
    Write-Output "✓ Perfiles WiFi exportados."
}
catch {
    Write-Warning "❌ Error al exportar perfiles WiFi."
}

Stop-Transcript

Write-Output "`n✅ Backup completado correctamente en: $backupPathDate"
