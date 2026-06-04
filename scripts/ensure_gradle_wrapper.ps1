# Ensures android/gradle/wrapper/gradle-wrapper.jar exists without storing the
# binary jar in git. The jar is extracted from the Gradle distribution declared
# in android/gradle/wrapper/gradle-wrapper.properties.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptPath
$wrapperDir = Join-Path $repoRoot 'android\gradle\wrapper'
$wrapperJar = Join-Path $wrapperDir 'gradle-wrapper.jar'
$wrapperProperties = Join-Path $wrapperDir 'gradle-wrapper.properties'

if (Test-Path $wrapperJar) {
    Write-Host 'Gradle wrapper JAR already exists.'
    exit 0
}

if (-not (Test-Path $wrapperProperties)) {
    throw "Missing Gradle wrapper properties at $wrapperProperties"
}

$properties = New-Object System.Collections.Specialized.OrderedDictionary
Get-Content $wrapperProperties | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#')) { return }
    $separator = $line.IndexOf('=')
    if ($separator -gt 0) {
        $key = $line.Substring(0, $separator).Trim()
        $value = $line.Substring($separator + 1).Trim().Replace('\:', ':')
        $properties[$key] = $value
    }
}

$distributionUrl = $properties['distributionUrl']
if (-not $distributionUrl) {
    throw "distributionUrl is missing from $wrapperProperties"
}

$distributionFile = [System.IO.Path]::GetFileName(([Uri]$distributionUrl).AbsolutePath)
if (-not $distributionFile.EndsWith('.zip')) {
    throw "Unsupported Gradle distribution URL: $distributionUrl"
}

$gradleVersionMatch = [regex]::Match($distributionFile, 'gradle-(.+?)-(?:bin|all)\.zip')
if (-not $gradleVersionMatch.Success) {
    throw "Could not determine Gradle version from $distributionFile"
}
$gradleVersion = $gradleVersionMatch.Groups[1].Value

$cacheRoot = Join-Path $env:TEMP 'chessai-gradle-wrapper'
$distributionZip = Join-Path $cacheRoot $distributionFile
$distributionExtractDir = Join-Path $cacheRoot ("gradle-$gradleVersion")
$wrapperMainJar = Join-Path $distributionExtractDir "gradle-$gradleVersion\lib\plugins\gradle-wrapper-main-$gradleVersion.jar"

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
New-Item -ItemType Directory -Force -Path $wrapperDir | Out-Null

if (-not (Test-Path $distributionZip)) {
    Write-Host "Downloading Gradle distribution from $distributionUrl"
    Invoke-WebRequest -Uri $distributionUrl -OutFile $distributionZip
}

if (-not (Test-Path $wrapperMainJar)) {
    Write-Host 'Extracting Gradle wrapper main jar from distribution.'
    if (Test-Path $distributionExtractDir) {
        Remove-Item -LiteralPath $distributionExtractDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $distributionExtractDir | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($distributionZip, $distributionExtractDir)
}

if (-not (Test-Path $wrapperMainJar)) {
    throw "Could not find $wrapperMainJar after extracting $distributionZip"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$wrapperMainZip = [System.IO.Compression.ZipFile]::OpenRead($wrapperMainJar)
try {
    $entry = $wrapperMainZip.Entries | Where-Object { $_.FullName -eq 'gradle-wrapper.jar' } | Select-Object -First 1
    if (-not $entry) {
        throw "gradle-wrapper.jar was not found inside $wrapperMainJar"
    }
    if (Test-Path $wrapperJar) {
        Remove-Item -LiteralPath $wrapperJar -Force
    }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $wrapperJar)
}
finally {
    $wrapperMainZip.Dispose()
}

Write-Host "Created $wrapperJar"
