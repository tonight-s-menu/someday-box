#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_FILE="${REPOSITORY_ROOT}/SomedayBox.xcodeproj/project.pbxproj"
readonly PRIVACY_MANIFEST="${REPOSITORY_ROOT}/Resources/PrivacyInfo.xcprivacy"
readonly PACKAGE_MANIFEST="${REPOSITORY_ROOT}/Package.swift"
readonly ALLOWED_ENTITLEMENTS='com.apple.developer.default-data-protection|com.apple.security.application-groups'
readonly ALLOWED_ENTITLEMENT_KEY_PATH='com\.apple\.developer\.default-data-protection'

failures=0

pass() {
    echo "[local-only audit] PASS: $1"
}

fail() {
    echo "[local-only audit] FAIL: $1" >&2
    failures=$((failures + 1))
}

report_matches() {
    local label="$1"
    local pattern="$2"
    shift 2
    local matches
    if matches="$(rg -n --glob '*.swift' --regexp "${pattern}" "$@")"; then
        fail "${label}"
        echo "${matches}" >&2
    else
        pass "${label}"
    fi
}

cd "${REPOSITORY_ROOT}"

readonly -a PRODUCTION_SOURCE_ROOTS=(App Application Data Domain Features DesignSystem ShareExtension)
report_matches \
    "production Swift contains no networking, web-view, authentication-session, or CloudKit API" \
    'https?://|(^|[^[:alnum:]_])(URLSession|URLSessionConfiguration|WebView|WKWebView|WKNavigationDelegate|SFSafariViewController|ASWebAuthenticationSession|CKContainer|CKDatabase|CKRecord|NWConnection|NWBrowser)([^[:alnum:]_]|$)|^[[:space:]]*import[[:space:]]+(WebKit|CloudKit|Network)([[:space:]]|$)' \
    "${PRODUCTION_SOURCE_ROOTS[@]}"

report_matches \
    "production Swift contains no user-content logging surface" \
    '(^|[^[:alnum:]_])(print|debugPrint|dump|NSLog|os_log|Logger)[[:space:]]*\(' \
    "${PRODUCTION_SOURCE_ROOTS[@]}"

report_matches \
    "Share Extension contains no containing-app singleton access" \
    'UIApplication[.]shared|NSWorkspace[.]shared|openURL[[:space:]]*\(' \
    ShareExtension

if rg -n 'XC(Remote|Local)SwiftPackageReference|XCSwiftPackageProductDependency|packageReferences[[:space:]]*=' "${PROJECT_FILE}"; then
    fail "Xcode project declares no Swift package dependency"
else
    pass "Xcode project declares no Swift package dependency"
fi

if rg -n '\.package[[:space:]]*\(' "${PACKAGE_MANIFEST}"; then
    fail "Package.swift declares no external package dependency"
else
    pass "Package.swift declares no external package dependency"
fi

if rg --files -g 'Package.resolved' -g '!**/.build/**' | grep -q .; then
    fail "repository contains no resolved external package graph"
else
    pass "repository contains no resolved external package graph"
fi

if rg -n 'SystemCapabilities|com\.apple\.CloudKit|iCloud|aps-environment|INFOPLIST_KEY_NS(Camera|Microphone|PhotoLibrary|Location|Contacts|Calendars|Reminders|Bluetooth|Motion|Health|HomeKit|LocalNetwork).*UsageDescription|NSBonjourServices' "${PROJECT_FILE}"; then
    fail "project declares no CloudKit, push, local-network, or sensitive-device capability"
else
    pass "project declares no CloudKit, push, local-network, or sensitive-device capability"
fi

entitlement_files="$(rg --files -g '*.entitlements' -g '!**/.build/**')"
if [[ -z "${entitlement_files}" ]]; then
    fail "at least one reviewed entitlements file exists"
else
    while IFS= read -r entitlement_file; do
        if ! plutil -lint "${entitlement_file}" >/dev/null; then
            fail "${entitlement_file} is a valid property list"
            continue
        fi
        entitlement_keys="$(plutil -p "${entitlement_file}" | sed -n 's/^[[:space:]]*"\([^"]*\)" =>.*/\1/p')"
        while IFS= read -r entitlement_key; do
            [[ -z "${entitlement_key}" ]] && continue
            if ! [[ "${entitlement_key}" =~ ^(${ALLOWED_ENTITLEMENTS})$ ]]; then
                fail "${entitlement_file} contains unapproved entitlement ${entitlement_key}"
            fi
        done <<< "${entitlement_keys}"
    done <<< "${entitlement_files}"

    protection_value="$(plutil -extract "${ALLOWED_ENTITLEMENT_KEY_PATH}" raw "${REPOSITORY_ROOT}/SomedayBox.entitlements" 2>/dev/null || true)"
    if [[ "${protection_value}" == "NSFileProtectionComplete" ]]; then
        pass "source entitlements contain only reviewed complete data protection"
    else
        fail "SomedayBox.entitlements must set complete data protection"
    fi
fi

for entitlement_file in SomedayBox.entitlements ShareExtension/ShareExtension.entitlements; do
    group_identifier="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "${entitlement_file}" 2>/dev/null || true)"
    if [[ "${group_identifier}" == "group.com.somedaybox.app.share" ]]; then
        pass "${entitlement_file} contains the reviewed Share to Box App Group"
    else
        fail "${entitlement_file} must contain only the reviewed Share to Box App Group"
    fi
done

if ! plutil -lint "${PRIVACY_MANIFEST}" >/dev/null; then
    fail "privacy manifest is a valid property list"
else
    tracking_value="$(plutil -extract NSPrivacyTracking raw "${PRIVACY_MANIFEST}" 2>/dev/null || true)"
    collected_data="$(plutil -extract NSPrivacyCollectedDataTypes json -o - "${PRIVACY_MANIFEST}" 2>/dev/null || true)"
    if [[ "${tracking_value}" == "false" && "${collected_data}" == "[]" ]]; then
        pass "privacy manifest declares no tracking and no collected data"
    else
        fail "privacy manifest must declare no tracking and no collected data"
    fi
fi

if rg -n --glob '*.swift' '(^|[^[:alnum:]_])(UserDefaults|@AppStorage)([^[:alnum:]_]|$)' "${PRODUCTION_SOURCE_ROOTS[@]}" >/dev/null; then
    privacy_json="$(plutil -convert json -o - "${PRIVACY_MANIFEST}")"
    if jq -e '
        any(
            .NSPrivacyAccessedAPITypes[]?;
            .NSPrivacyAccessedAPIType == "NSPrivacyAccessedAPICategoryUserDefaults"
            and (.NSPrivacyAccessedAPITypeReasons | index("CA92.1") != null)
        )
    ' <<< "${privacy_json}" >/dev/null; then
        pass "app-only UserDefaults access declares approved reason CA92.1"
    else
        fail "UserDefaults access requires app-only reason CA92.1"
    fi
fi

echo "[local-only audit] Evidence boundary: repository-source and project-configuration scan only."
echo "[local-only audit] It does not prove runtime network silence, signed-package entitlements, App Privacy Report results, device behavior, or packaged acceptance."

if (( failures > 0 )); then
    echo "[local-only audit] ${failures} check(s) failed." >&2
    exit 1
fi

echo "[local-only audit] Static local-only audit passed."
