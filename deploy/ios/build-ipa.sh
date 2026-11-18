#!/usr/bin/env bash
# Build IPA rilis untuk TestFlight / App Store.
#
# Pemakaian:
#   export GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
#   ./deploy/ios/build-ipa.sh            # pakai build number di pubspec.yaml
#   BUILD_NUMBER=14 ./deploy/ios/build-ipa.sh   # naikkan build number dulu
#
# Hasil: build/ios/archive/Runner.xcarchive dan build/ios/ipa/*.ipa
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-https://api.pusatoleolehpekanbaru.id/api}"
: "${GOOGLE_WEB_CLIENT_ID:?Isi GOOGLE_WEB_CLIENT_ID=<OAuth client tipe Web> dulu}"

cd "$(dirname "$0")/../.."

versi_lengkap="$(sed -n 's/^version: *//p' pubspec.yaml | head -1)"
versi_nama="${versi_lengkap%%+*}"
versi_build="${versi_lengkap##*+}"

if [ -n "${BUILD_NUMBER:-}" ]; then
  if ! printf '%s' "$BUILD_NUMBER" | grep -Eq '^[0-9]+$'; then
    echo "BUILD_NUMBER harus angka, dapat: $BUILD_NUMBER" >&2
    exit 1
  fi
  versi_build="$BUILD_NUMBER"
  sed -i '' "s/^version: .*/version: ${versi_nama}+${versi_build}/" pubspec.yaml
fi

echo "▸ Insyira ${versi_nama} (build ${versi_build})"
echo "▸ API   : ${API_BASE_URL}"

flutter clean
flutter pub get
(cd ios && pod install)

flutter build ipa --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"

echo
echo "Selesai. Upload lewat:"
echo "  open build/ios/archive/Runner.xcarchive   # Distribute App → App Store Connect"
echo "  atau seret build/ios/ipa/*.ipa ke Transporter"
