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

## Restauración

No existe un script automático de restauración. Esta herramienta de backup está diseñada para proporcionar los archivos necesarios para restaurar selectivamente solo los componentes que interesen en una instalación limpia o en otro equipo.

A continuación se detalla el procedimiento manual para restaurar cada componente:

### 1. Programas (WinGet)

Para reinstalar automáticamente los programas que fueron gestionados por WinGet:

```powershell
winget import -i "Ruta\A\winget_installed.json" --accept-package-agreements --accept-source-agreements
```
Podemos modificar el archivo `winget_installed.json` para quitar programas que no queramos reinstalar.

También podemos instalar programas individualmente o en grupo si no desea restaurar todo el listado.

**Instalar un solo programa (ej. VS Code):**
```powershell
winget install Microsoft.VisualStudioCode
```

**Instalar varios programas a la vez (ej. VS Code, 7zip y Git):**
```powershell
winget install Microsoft.VisualStudioCode 7zip.7zip Git.Git
```

### 2. Otros Programas

Revisar el archivo `installed_apps.txt` y `store_apps.txt` para identificar qué otro software necesita instalar manualmente o descargar desde la Microsoft Store.

### 3. Visual Studio Code

Para restaurar la configuración, extensiones y atajos de teclado:

1.  Asegúrese de que VS Code esté cerrado.
2.  Copie el contenido de la carpeta `VSCodeConfig` del backup.
3.  Pegue y reemplace los archivos en `%APPDATA%\Code\User` (generalmente `C:\Users\SuUsuario\AppData\Roaming\Code\User`).

### 4. WSL (Subsistema de Linux)

Para importar una distribución completa:

```powershell
wsl --import <NombreDistro> <RutaInstalacion> "Ruta\A\distro-backup.tar"
```

Ejemplo:
```powershell
wsl --import Ubuntu-22.04 C:\WSL\Ubuntu "D:\Backups\WSL\Ubuntu\Ubuntu-backup.tar"
```

### 5. Perfiles WiFi

Para restaurar una red WiFi conocida:

```powershell
netsh wlan add profile filename="Ruta\A\WiFi-NombreRed.xml"
```

### 6. Drivers

Para instalar drivers respaldados (útil si faltan controladores después de una instalación limpia):

1.  Abra el Administrador de Dispositivos.
2.  Haga clic derecho sobre el dispositivo desconocido o driver a actualizar.
3.  Seleccione "Actualizar controlador" > "Buscar controladores en mi equipo".
4.  Seleccione la carpeta `Drivers` de su backup y marque "Incluir subcarpetas".
