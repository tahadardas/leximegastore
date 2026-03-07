param(
  [int[]]$ApiLevels = @(33, 36)
)

$ErrorActionPreference = 'Stop'

function Get-AndroidSdkPath {
  if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
    return $env:ANDROID_SDK_ROOT
  }
  if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
    return $env:ANDROID_HOME
  }

  $localProps = Join-Path (Get-Location) 'android\local.properties'
  if (Test-Path $localProps) {
    $line = Select-String -Path $localProps -Pattern '^sdk\.dir=' | Select-Object -First 1
    if ($line) {
      $value = $line.Line.Substring('sdk.dir='.Length).Trim()
      if ($value) {
        $sdkDir = $value -replace '\\\\', '\'
        if (Test-Path $sdkDir) {
          return $sdkDir
        }
      }
    }
  }

  throw "Android SDK path not found. Set ANDROID_SDK_ROOT or ANDROID_HOME, or configure android/local.properties."
}

function Get-SdkManagerPath([string]$sdkPath) {
  $candidates = @(
    (Join-Path $sdkPath 'cmdline-tools\latest\bin\sdkmanager.bat'),
    (Join-Path $sdkPath 'cmdline-tools\bin\sdkmanager.bat'),
    (Join-Path $sdkPath 'tools\bin\sdkmanager.bat')
  )

  foreach ($path in $candidates) {
    if (Test-Path $path) {
      return $path
    }
  }

  throw "sdkmanager.bat not found under $sdkPath. Install Android SDK Command-line Tools from Android Studio."
}

function Ensure-Platform([string]$sdkPath, [string]$sdkManager, [int]$api) {
  $jarPath = Join-Path $sdkPath "platforms\android-$api\android.jar"
  if (Test-Path $jarPath) {
    Write-Host "OK: android-$api found -> $jarPath"
    return
  }

  Write-Host "MISSING: android-$api (android.jar not found). Installing..."
  & $sdkManager --sdk_root=$sdkPath "platforms;android-$api" | Out-Host

  if (-not (Test-Path $jarPath)) {
    throw "Failed to install platforms;android-$api. android.jar is still missing."
  }

  Write-Host "INSTALLED: android-$api -> $jarPath"
}

$sdkPath = Get-AndroidSdkPath
$sdkManager = Get-SdkManagerPath -sdkPath $sdkPath

Write-Host "Android SDK: $sdkPath"
Write-Host "sdkmanager: $sdkManager"

foreach ($api in $ApiLevels) {
  Ensure-Platform -sdkPath $sdkPath -sdkManager $sdkManager -api $api
}

Write-Host "Done. You can now run:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter build apk --release"
