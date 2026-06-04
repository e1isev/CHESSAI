# Android device export/build fix instructions

Use these steps if exporting, building, or running the Android app on a phone fails.

## 1. Go to the repo root

```powershell
cd C:\Users\eliss\CHESSAI
```

## 2. Pull the latest fix

Binary files are not stored in this repository, so the helper script recreates the required Gradle wrapper JAR locally before running Android build commands.

```powershell
git status
git pull
```

If `git pull` says you have unmerged files, see [Resolve merge conflicts](#resolve-merge-conflicts).

## 3. Refresh the Android Gradle files

```powershell
.\FIX_ANDROID_BUILD.bat
flutter run
```

The helper recreates `android\gradle\wrapper\gradle-wrapper.jar` locally and keeps the modern Flutter Gradle plugin setup. `android\app\build.gradle` should start with:

```gradle
plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android"
    id "dev.flutter.flutter-gradle-plugin"
}
```

Do not replace it with the old `apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"` setup; recent Flutter versions reject that legacy plugin application style.

The generated wrapper JAR remains ignored by git because binary files are not supported in PR diffs.

## 4. If Gradle cannot find Flutter

Run Flutter once from the repository root so it creates `android\local.properties`:

```powershell
flutter pub get
```

If you still see `Flutter SDK not found`, create `android\local.properties` manually and point it to your Flutter SDK path:

```properties
flutter.sdk=C:\path\to\flutter
```

## Resolve merge conflicts

If Git is paused in the middle of a merge conflict, abort the merge or finish resolving conflicts before another pull can work.

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
