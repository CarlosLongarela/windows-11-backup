# Windows 11 Backup Script

Este script de PowerShell automatiza la creación de copias de seguridad de configuraciones críticas, programas instalados y datos del sistema en Windows 11.

## Requisitos

- Windows 10 o Windows 11.
- PowerShell 5.1 o superior.
- **Permisos de Administrador**: El script debe ejecutarse con privilegios elevados para exportar drivers, perfiles WiFi y acceder a ciertas configuraciones del sistema.
- `winget` instalado (generalmente incluido en Windows 11).
- `wsl` instalado (si se desea hacer backup de subsistemas Linux).

## Funcionalidades

El script realiza las siguientes acciones de forma secuencial:

1.  **Registro de actividad**: Crea un archivo de log con todo el proceso.
2.  **Programas instalados (WinGet)**: Exporta la lista de paquetes instalados gestionados por WinGet a formato JSON.
3.  **Programas del sistema**: Genera un listado de texto con todo el software instalado detectado en el Registro de Windows (versiones de 32 y 64 bits).
4.  **Apps de Microsoft Store**: Lista todas las aplicaciones instaladas desde la tienda de Microsoft.
5.  **Configuración de VS Code**: Realiza una copia completa de la carpeta de usuario de Visual Studio Code (`%APPDATA%\Code\User`).
6.  **WSL2 (Windows Subsystem for Linux)**:
    - Detecta automáticamente las distribuciones instaladas.
    - Exporta cada distribución completa a un archivo `.tar`.
    - Exporta independientemente el directorio `/home` de cada distribución para facilitar la recuperación de datos de usuario.
7.  **Drivers**: Exporta todos los controladores de terceros instalados en el sistema usando DISM.
8.  **Redes WiFi**: Exporta los perfiles de redes WiFi guardados, incluyendo las contraseñas en texto plano (útil para restaurar conexiones).

## Uso

1.  Abra PowerShell como Administrador.
2.  Navegue hasta la carpeta donde se encuentra el script.
3.  Ejecute el script:

```powershell
.\win-11-backup.ps1
```

Por defecto, la copia de seguridad se guardará en `D:\BackupWindows11\[FECHA_HORA]`.

## Parámetros

El script acepta un parámetro opcional para definir la ruta de destino.

### -backupPath

Define el directorio raíz donde se almacenarán las copias de seguridad.

**Tipo**: String
**Valor por defecto**: `D:\BackupWindows11`

**Ejemplo de uso con ruta personalizada**:

```powershell
.\win-11-backup.ps1 -backupPath "C:\MisBackups"
```

## Estructura de la Copia de Seguridad

El script crea una carpeta con la fecha y hora actual (formato `yyyy-MM-dd_HH-mm`) que contiene:

- `backup_log.txt`: Registro de la ejecución.
- `winget_installed.json`: Archivo de importación para WinGet.
- `installed_apps.txt`: Lista legible de programas instalados.
- `store_apps.txt`: Lista de apps de la tienda.
- `VSCodeConfig\`: Carpeta con la configuración de VS Code.
- `WSL\`: Carpeta con las exportaciones de las distribuciones Linux.
- `Drivers\`: Carpeta con los controladores exportados.
- `WiFi\`: Archivos XML con la configuración de cada red WiFi.
