#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 /absolute/path/to/SomedayBox.xcarchive" >&2
    exit 64
fi

readonly ARCHIVE_PATH="$1"
readonly ARCHIVE_INFO="${ARCHIVE_PATH}/Info.plist"
readonly APP_ENTITLEMENTS="$(mktemp)"
readonly EXTENSION_ENTITLEMENTS="$(mktemp)"
trap 'rm -f "${APP_ENTITLEMENTS}" "${EXTENSION_ENTITLEMENTS}"' EXIT

fail() {
    echo "[share package audit] FAIL: $1" >&2
    exit 1
}

pass() {
    echo "[share package audit] PASS: $1"
}

[[ -d "${ARCHIVE_PATH}" ]] || fail "archive directory does not exist"
[[ -f "${ARCHIVE_INFO}" ]] || fail "archive Info.plist is missing"

application_path="$(plutil -extract ApplicationProperties.ApplicationPath raw "${ARCHIVE_INFO}" 2>/dev/null || true)"
[[ -n "${application_path}" ]] || fail "archive does not declare an application path"

readonly APP_PATH="${ARCHIVE_PATH}/Products/${application_path}"
readonly EXTENSION_PATH="${APP_PATH}/PlugIns/ShareExtension.appex"
readonly EXTENSION_INFO="${EXTENSION_PATH}/Info.plist"

[[ -d "${APP_PATH}" ]] || fail "archived application is missing"
[[ -d "${EXTENSION_PATH}" ]] || fail "ShareExtension.appex is not embedded"
[[ -f "${EXTENSION_INFO}" ]] || fail "embedded extension Info.plist is missing"
pass "archive embeds ShareExtension.appex"

extension_point="$(plutil -extract NSExtension.NSExtensionPointIdentifier raw "${EXTENSION_INFO}")"
[[ "${extension_point}" == "com.apple.share-services" ]] || fail "extension point is not com.apple.share-services"
pass "extension point is com.apple.share-services"

activation_version="$(plutil -extract NSExtension.NSExtensionAttributes.NSExtensionActivationRule.NSExtensionActivationDictionaryVersion raw "${EXTENSION_INFO}")"
strict_matching="$(plutil -extract NSExtension.NSExtensionAttributes.NSExtensionActivationRule.NSExtensionActivationUsesStrictMatching raw "${EXTENSION_INFO}")"
text_support="$(plutil -extract NSExtension.NSExtensionAttributes.NSExtensionActivationRule.NSExtensionActivationSupportsText raw "${EXTENSION_INFO}")"
url_count="$(plutil -extract NSExtension.NSExtensionAttributes.NSExtensionActivationRule.NSExtensionActivationSupportsWebURLWithMaxCount raw "${EXTENSION_INFO}")"

[[ "${activation_version}" == "2" ]] || fail "activation dictionary version is not 2"
[[ "${strict_matching}" == "true" ]] || fail "strict activation matching is not enabled"
[[ "${text_support}" == "true" ]] || fail "plain-text activation is not enabled"
[[ "${url_count}" == "1" ]] || fail "URL activation max count is not 1"
pass "activation rule is strict URL/text-only v2"

if plutil -p "${EXTENSION_INFO}" | rg -q 'TRUEPREDICATE|UIBackgroundModes|Supports(Image|Movie|File|WebPage)'; then
    fail "embedded extension contains a prohibited activation or background declaration"
fi
pass "embedded extension contains no prohibited activation or background declaration"

if codesign -d --entitlements :- "${APP_PATH}" >"${APP_ENTITLEMENTS}" 2>/dev/null \
    && codesign -d --entitlements :- "${EXTENSION_PATH}" >"${EXTENSION_ENTITLEMENTS}" 2>/dev/null; then
    app_group="$(plutil -extract com.apple.security.application-groups.0 raw "${APP_ENTITLEMENTS}")"
    extension_group="$(plutil -extract com.apple.security.application-groups.0 raw "${EXTENSION_ENTITLEMENTS}")"
    [[ "${app_group}" == "group.com.somedaybox.app.share" ]] || fail "signed app App Group is unexpected"
    [[ "${extension_group}" == "${app_group}" ]] || fail "signed app and extension App Groups differ"
    pass "signed app and extension carry the reviewed App Group"
else
    echo "[share package audit] NOT PROVEN: archive is unsigned; signed entitlements require a distribution candidate"
fi

echo "[share package audit] Evidence boundary: archive structure and embedded configuration only."
echo "[share package audit] This does not prove real-host, physical-device, runtime-network, or installed signed-candidate behavior."
