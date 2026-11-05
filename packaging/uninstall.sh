#!/bin/bash
# Removes Deye Monitor for all users. Run: sudo bash uninstall.sh
set -e
AGENT=/Library/LaunchAgents/ua.com.mrigne.deyemonitor.plist
LEGACY=/Library/LaunchAgents/dev.deye.monitor.plist   # 1.0.0
for uid in $(ps -axo uid=,comm= | awk '/DeyeMonitor$/ {print $1}' | sort -u); do
    launchctl bootout "gui/$uid" "$AGENT" 2>/dev/null || true
    launchctl bootout "gui/$uid" "$LEGACY" 2>/dev/null || true
done
pkill -x DeyeMonitor 2>/dev/null || true
rm -f "$AGENT" "$LEGACY" /Library/Preferences/ua.com.mrigne.deyemonitor.plist /Library/Preferences/dev.deye.monitor.plist
rm -rf "/Applications/Deye Monitor.app"
pkgutil --forget ua.com.mrigne.deyemonitor.pkg 2>/dev/null || true
pkgutil --forget dev.deye.monitor.pkg 2>/dev/null || true
echo "Deye Monitor removed. Per-user data stays in ~/Library/Application Support/DeyeMonitor."
