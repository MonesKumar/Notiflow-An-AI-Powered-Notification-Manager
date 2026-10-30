#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required on your development computer.' >&2
  exit 1
fi
bootstrap_dir="$(mktemp -d)"
trap 'rm -rf "$bootstrap_dir"' EXIT
flutter create --platforms=android --project-name notiflow "$bootstrap_dir/notiflow"
cp "$bootstrap_dir/notiflow/android/gradlew" android/gradlew
cp "$bootstrap_dir/notiflow/android/gradlew.bat" android/gradlew.bat
cp "$bootstrap_dir/notiflow/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
chmod +x android/gradlew
flutter pub get
printf 'Gradle wrapper ready. Run: flutter build apk --debug\n'
