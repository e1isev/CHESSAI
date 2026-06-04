# Android build fix instructions

If PowerShell says this file does not exist:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\replace_android_gradle_files.ps1
```

then your local checkout does not have the latest fix files yet, or you are not running the command from the repository root.

## 1. Go to the repo root

```powershell
cd C:\Users\eliss\CHESSAI
```

## 2. Confirm the helper files exist

```powershell
Test-Path .\scripts\replace_android_gradle_files.ps1
Test-Path .\FIX_ANDROID_BUILD.bat
```

Both commands should print `True`.

If either command prints `False`, pull the latest branch or merge the PR that added those files.

```powershell
git status
git pull
```

## 3. Run the one-click fixer

```powershell
.\FIX_ANDROID_BUILD.bat
flutter run
```

## 4. If you cannot pull the helper files

Manually check `android\app\build.gradle`. It should start with:

```gradle
def localProperties = new Properties()
```

It should not start with:

```gradle
plugins {
```

If it starts with `plugins {`, your local Android Gradle file is still the version that triggers the `dev.flutter.flutter-gradle-plugin` failure.

## 5. If `git pull` says you have unmerged files

This means Git is currently paused in the middle of a merge conflict. You must either abort the merge or finish resolving conflicts before another `git pull` can work.

### Option A: discard the conflicted local merge and pull again

Use this if you do not need to keep local edits:

```powershell
git merge --abort
git status
git pull
```

If `git merge --abort` says there is no merge to abort, use:

```powershell
git reset --hard HEAD
git clean -fd
git pull
```

### Option B: resolve the conflict manually

Use this if you need to keep local edits:

```powershell
git status
```

Open each file listed as unmerged, remove the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), save the file, then mark it resolved:

```powershell
git add <file-that-you-fixed>
git commit
```

After the merge commit completes, run:

```powershell
git pull
```
