#!/bin/bash
# Builds dist/DeyeMonitor-<version>.pkg — installs Deye Monitor for all users.
#
#   ./build_pkg.sh                         # version 1.0, ad-hoc signed (this Mac only)
#   VERSION=1.2.0 ./build_pkg.sh           # explicit version (CI passes the git tag)
#   ./build_pkg.sh --prefill path/to/.env  # preset INVERTER_IP / LOGGER_SERIAL for all users
#
# Signed + notarized build (installs cleanly on any Mac) — set:
#   TEAM_ID=ABCDE12345
#   APP_SIGN_IDENTITY="Developer ID Application: Your Name (ABCDE12345)"
#   PKG_SIGN_IDENTITY="Developer ID Installer: Your Name (ABCDE12345)"
#   and either NOTARY_PROFILE=<keychain profile from `xcrun notarytool store-credentials`>
#   or NOTARY_KEY_PATH=AuthKey_XXXX.p8 NOTARY_KEY_ID=XXXX NOTARY_ISSUER=<uuid>
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$HERE/.."
VERSION="${VERSION:-1.0}"
PREFILL_ENV=""
if [ "${1:-}" = "--prefill" ]; then PREFILL_ENV="${2:?path to .env}"; fi

BUILD="$PROJ/build"
STAGE="$PROJ/build/pkgroot"
DIST="$PROJ/dist"
PKG="$DIST/DeyeMonitor-$VERSION.pkg"
rm -rf "$STAGE" && mkdir -p "$STAGE/Applications" "$STAGE/Library/LaunchAgents" "$DIST"

SIGN_ARGS=()
if [ -n "${APP_SIGN_IDENTITY:-}" ]; then
    : "${TEAM_ID:?TEAM_ID is required for Developer ID signing}"
    echo "==> Signing with: $APP_SIGN_IDENTITY"
    SIGN_ARGS=(CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM_ID"
               CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY"
               ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp
               # Xcode otherwise injects get-task-allow (debugger attach),
               # which makes notarization reject the build.
               CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
else
    echo "==> No APP_SIGN_IDENTITY: ad-hoc signing (runs on this Mac; other Macs will warn)"
fi

echo "==> Building Deye Monitor $VERSION"
xcodebuild -project "$PROJ/DeyeMonitor.xcodeproj" -scheme DeyeMonitor -configuration Release \
    -derivedDataPath "$BUILD" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
    ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} build -quiet

ditto "$BUILD/Build/Products/Release/Deye Monitor.app" "$STAGE/Applications/Deye Monitor.app"
cp "$HERE/ua.com.mrigne.deyemonitor.plist" "$STAGE/Library/LaunchAgents/"

if [ -n "$PREFILL_ENV" ]; then
    IP=$(grep -E '^INVERTER_IP=' "$PREFILL_ENV" | cut -d= -f2- | tr -d '"' || true)
    SN=$(grep -E '^LOGGER_SERIAL=' "$PREFILL_ENV" | cut -d= -f2- | tr -d '"' || true)
    if [ -n "$IP" ] && [ -n "$SN" ]; then
        mkdir -p "$STAGE/Library/Preferences"
        PREF="$STAGE/Library/Preferences/ua.com.mrigne.deyemonitor.plist"
        /usr/libexec/PlistBuddy -c "Add :InverterIP string $IP" -c "Add :LoggerSerial string $SN" "$PREF" >/dev/null
        echo "==> Prefilled inverter $IP / logger $SN for all users"
    fi
fi

# Strip extended attributes so the payload has no AppleDouble (._*) files
# (com.apple.provenance can't be removed locally; harmless).
xattr -cr "$STAGE" 2>/dev/null || true
export COPYFILE_DISABLE=1

# Never let Installer "relocate" the app to another copy with the same bundle id.
COMPONENTS="$BUILD/components.plist"
pkgbuild --analyze --root "$STAGE" "$COMPONENTS" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$COMPONENTS"

pkgbuild --root "$STAGE" --component-plist "$COMPONENTS" --scripts "$HERE/scripts" \
    --identifier ua.com.mrigne.deyemonitor.pkg --version "$VERSION" --install-location / \
    "$BUILD/DeyeMonitor-component.pkg" >/dev/null

PB_SIGN=()
[ -n "${PKG_SIGN_IDENTITY:-}" ] && PB_SIGN=(--sign "$PKG_SIGN_IDENTITY" --timestamp)
productbuild ${PB_SIGN[@]+"${PB_SIGN[@]}"} --package "$BUILD/DeyeMonitor-component.pkg" "$PKG" >/dev/null

# Notarize + staple, so Gatekeeper accepts the download without warnings.
if [ -n "${PKG_SIGN_IDENTITY:-}" ]; then
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        NOTARY=(--keychain-profile "$NOTARY_PROFILE")
    elif [ -n "${NOTARY_KEY_PATH:-}" ]; then
        NOTARY=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER:?}")
    else
        NOTARY=()
    fi
    if [ ${#NOTARY[@]} -gt 0 ]; then
        echo "==> Notarizing (usually 1–5 min)"
        OUT=$(xcrun notarytool submit "$PKG" "${NOTARY[@]}" --wait 2>&1) || true
        echo "$OUT"
        SUB_ID=$(echo "$OUT" | awk '/^ *id: /{print $2; exit}')
        if ! echo "$OUT" | grep -q "status: Accepted"; then
            echo "==> Notarization was rejected. Apple's log:"
            [ -n "$SUB_ID" ] && xcrun notarytool log "$SUB_ID" "${NOTARY[@]}" || true
            exit 1
        fi
        xcrun stapler staple "$PKG"
        spctl --assess --type install -vv "$PKG" || true
    else
        echo "==> Signed but NOT notarized (no NOTARY_PROFILE / NOTARY_KEY_PATH)"
    fi
fi

echo "==> $PKG"
