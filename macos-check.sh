#!/bin/bash

set -u

bool_to_json() {
  if [ "$1" = "true" ]; then
    echo "true"
  else
    echo "false"
  fi
}

HOSTNAME="$(scutil --get ComputerName 2>/dev/null || hostname)"
USER_NAME="$(whoami)"
CHECKED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OS_VERSION="$(sw_vers -productVersion 2>/dev/null)"
OS_BUILD="$(sw_vers -buildVersion 2>/dev/null)"

# Check Gatekeeper
GATEKEEPER_STATUS="$(spctl --status 2>/dev/null)"
if echo "$GATEKEEPER_STATUS" | grep -qi "assessments enabled"; then
  GATEKEEPER_ENABLED="true"
else
  GATEKEEPER_ENABLED="false"
fi

# Check XProtect
XPROTECT_VERSION="$(defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info CFBundleShortVersionString 2>/dev/null)"
MRT_VERSION="$(defaults read /Library/Apple/System/Library/CoreServices/MRT.app/Contents/Info CFBundleShortVersionString 2>/dev/null)"

if [ -n "${XPROTECT_VERSION:-}" ]; then
  XPROTECT_PRESENT="true"
else
  XPROTECT_PRESENT="false"
fi

# Check Firewall
FIREWALL_STATE="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)"
if echo "$FIREWALL_STATE" | grep -qi "enabled"; then
  FIREWALL_ENABLED="true"
else
  FIREWALL_ENABLED="false"
fi

# Check automatic updates
AUTO_CHECK="$(softwareupdate --schedule 2>/dev/null)"
if echo "$AUTO_CHECK" | grep -qi "on"; then
  AUTO_UPDATES_ENABLED="true"
else
  AUTO_UPDATES_ENABLED="false"
fi

AUTO_DOWNLOAD="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null || echo "")"
CRITICAL_INSTALL="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo "")"
CONFIG_DATA_INSTALL="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall 2>/dev/null || echo "")"

echo ""
echo "Running bigspark macOS security check..."
echo ""

cat <<JSON
{
  "hostname": "$HOSTNAME",
  "username": "$USER_NAME",
  "platform": "macos",
  "checked_at_utc": "$CHECKED_AT",
  "antivirus": {
    "gatekeeper_enabled": $(bool_to_json "$GATEKEEPER_ENABLED"),
    "xprotect_present": $(bool_to_json "$XPROTECT_PRESENT"),
    "xprotect_version": "${XPROTECT_VERSION:-unknown}",
    "mrt_version": "${MRT_VERSION:-unknown}"
  },
  "firewall": {
    "enabled": $(bool_to_json "$FIREWALL_ENABLED")
  },
  "updates": {
    "auto_updates_enabled": $(bool_to_json "$AUTO_UPDATES_ENABLED"),
    "automatic_download": "${AUTO_DOWNLOAD:-unknown}",
    "critical_update_install": "${CRITICAL_INSTALL:-unknown}",
    "config_data_install": "${CONFIG_DATA_INSTALL:-unknown}"
  },
  "patching": {
    "os_version": "$OS_VERSION",
    "os_build": "$OS_BUILD"
  },
  "summary": {
    "compliant_antivirus": $(bool_to_json "$([ "$GATEKEEPER_ENABLED" = "true" ] && [ "$XPROTECT_PRESENT" = "true" ] && echo true || echo false)"),
    "compliant_firewall": $(bool_to_json "$FIREWALL_ENABLED"),
    "compliant_auto_updates": $(bool_to_json "$AUTO_UPDATES_ENABLED")
  }
}
JSON

echo ""
echo "Check complete."
echo ""
echo "Summary:"
echo "Antivirus compliant: $([ "$GATEKEEPER_ENABLED" = "true" ] && [ "$XPROTECT_PRESENT" = "true" ] && echo YES || echo NO)"
echo "Firewall enabled: $([ "$FIREWALL_ENABLED" = "true" ] && echo YES || echo NO)"
echo "Automatic updates enabled: $([ "$AUTO_UPDATES_ENABLED" = "true" ] && echo YES || echo NO)"
echo ""
