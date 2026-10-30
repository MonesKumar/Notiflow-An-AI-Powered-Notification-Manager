# Notiflow — Android prototype

A Flutter Material 3 local inbox backed by Android's `NotificationListenerService` and app-private SQLite. **The classifier is deterministic rules plus explicit per-app preferences; it is not a trained ML model.** The report's earlier four buckets differ from the current brief; this build follows the brief: Critical/red, Important/orange, Social/blue, Promotional/gray.

## Build on a computer with Flutter and the Android SDK

1. Install Flutter stable, Android SDK/platform tools, and Java 17. Accept Android licenses with `flutter doctor --android-licenses`; check with `flutter doctor -v`.
2. In this project folder, run `./bootstrap_android.sh`. This obtains the standard Gradle wrapper from a temporary Flutter project without overwriting the Notiflow native code. Internet is needed to fetch Flutter/Gradle/Android build dependencies on the build computer, but **the installed app needs no internet**.
3. Run `flutter build apk --debug` (or `flutter run` with an Android device attached). Output: `build/app/outputs/flutter-apk/app-debug.apk`.
4. Install with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`, or use `flutter run`.

If your Flutter version requires a newer Android Gradle Plugin or Kotlin plugin, update the versions in `android/settings.gradle.kts` together with its supported Gradle distribution in `android/gradle/wrapper/gradle-wrapper.properties`. This source has not been compiled in the delivery environment because Flutter, Gradle, Android SDK and an emulator/device are absent there.

## Evaluation walkthrough

1. Launch Notiflow. Tap **Get started** → **Open Android access settings** → select Notiflow and allow notification access. Return to the app; it refreshes on resume. Android may show its own restricted-settings warning for sideloaded builds; follow Android's user-controlled settings flow if needed.
2. Post a real notification from another app. Supported entries appear in Home/Inbox; notification details show source and time. Some Android versions/apps redact content, which will display as missing text.
3. Tap **Load sample notifications** in Settings or the science icon on Home. Every simulated entry is tagged **SIMULATED**. This requires no permission.
4. Open the Chat sample (Social), select **Important**, then load the samples again. New Chat samples use the saved app preference. A critical phrase still takes precedence. Settings displays and can remove the preference.
5. Search/filter items, mark one read by opening it, delete its local copy, or clear all local history. These actions never alter the system notification. Tap **Open associated app** on a real entry if Android exposes its launcher.

## Implementation details and limits

- Native service: `android/app/src/main/kotlin/com/notiflow/app/NotiflowListener.kt`. App-side Kotlin SQLite store and classifier: `Store.kt`, `Classifier.kt`. Flutter interface: `lib/main.dart`. A MethodChannel bridges them; Home/Inbox refresh every five seconds while open and on return from background. Listener writes even when the Flutter UI is closed, subject to Android service delivery.
- Captures app label/package, title, text, and timestamp from delivered notifications; skips own, ongoing and group-summary events. Recognized OTP/password alerts have title and body replaced before storage. This is a best-effort sensitive-content filter, not a guarantee for every format. Source content is not transmitted, and the app declares no INTERNET permission. Storage is app-private but **not encrypted**. The database retains the latest 5,000 entries; Android/app restrictions can prevent delivery.
- Category correction sets an app-wide preference, intentionally simple and reversible. Such preferences may be too broad for apps with mixed kinds of messages. Critical keyword rules override them. Unknown items default to visible Important. There is no notification suppression, model training, accuracy claim, background auto-action, or cloud sync.
- `allowBackup=false` prevents normal Android backup of local content. Clear History leaves preferences intact; Reset Preferences removes them separately. Uninstalling removes app-private data. Access can be revoked in Android settings.

## Verification status

Source-level checks were performed on the package structure and integration contracts. The delivery environment has no Flutter/Dart, Gradle, Android SDK, emulator, or connected device, so compilation, runtime behavior, and APK generation still require the build computer and a real Android test. Run `flutter analyze`, `flutter test`, and the walkthrough above after bootstrapping.
