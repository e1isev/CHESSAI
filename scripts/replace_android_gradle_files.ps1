# Replaces the Android Gradle files with the modern Flutter Gradle setup and
# upgraded toolchain versions expected by this project.
#
# Run from the repository root on Windows:
#   powershell -ExecutionPolicy Bypass -File scripts\replace_android_gradle_files.ps1
# Or double-click/run from repo root:
#   FIX_ANDROID_BUILD.bat

Set-StrictMode -Version Latest

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptPath
$androidDir = Join-Path $repoRoot 'android'
$appBuildGradle = Join-Path $androidDir 'app\build.gradle'
$settingsGradle = Join-Path $androidDir 'settings.gradle'
$rootBuildGradle = Join-Path $androidDir 'build.gradle'
$gradleProperties = Join-Path $androidDir 'gradle.properties'
$wrapperProperties = Join-Path $androidDir 'gradle\wrapper\gradle-wrapper.properties'
$ensureWrapperScript = Join-Path $scriptPath 'ensure_gradle_wrapper.ps1'

$appBuildGradleContent = @'
plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace = "com.example.chess_ai_coach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        applicationId = "com.example.chess_ai_coach"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.debug
        }
    }
}

flutter {
    source = '../..'
}
'@

$settingsGradleContent = @'
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        def localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.withInputStream { properties.load(it) }
        }

        def flutterSdkPath = properties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")
        if (flutterSdkPath == null) {
            throw new GradleException("Flutter SDK not found. Run `flutter pub get` from the repository root or define flutter.sdk in android/local.properties.")
        }
        return flutterSdkPath
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.11.1" apply false
    id "org.jetbrains.kotlin.android" version "2.0.21" apply false
}

include ':app'
'@

$rootBuildGradleContent = @'
buildscript {
    ext.kotlin_version = '2.0.21'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.11.1'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = "../build"
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
'@

$gradlePropertiesContent = @'
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
'@

$wrapperPropertiesContent = @'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14.4-all.zip
'@

$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
[System.IO.File]::WriteAllText($appBuildGradle, $appBuildGradleContent, $utf8NoBom)
[System.IO.File]::WriteAllText($settingsGradle, $settingsGradleContent, $utf8NoBom)
[System.IO.File]::WriteAllText($rootBuildGradle, $rootBuildGradleContent, $utf8NoBom)
[System.IO.File]::WriteAllText($gradleProperties, $gradlePropertiesContent, $utf8NoBom)
[System.IO.File]::WriteAllText($wrapperProperties, $wrapperPropertiesContent, $utf8NoBom)

& $ensureWrapperScript

$pathsToRemove = @(
    (Join-Path $androidDir '.gradle'),
    (Join-Path $repoRoot 'build')
)

foreach ($pathToRemove in $pathsToRemove) {
    if (Test-Path $pathToRemove) {
        Remove-Item -LiteralPath $pathToRemove -Recurse -Force
    }
}

Write-Host 'Replaced Android Gradle files with the modern Flutter plugin setup.'
Write-Host 'Removed stale Android/Flutter build caches.'
Write-Host 'Next: run flutter clean; flutter pub get; flutter run'
