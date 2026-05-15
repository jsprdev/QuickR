#!/bin/bash
APP_ID=app.faith.quickr
APP_NAME=Quickr
APP_PATH=/Users/pichu1257/Library/Developer/Xcode/DerivedData/Quickr-aqhqmloxbeewbvdzpvnceapuyuff/Build/Products/Debug/Quickr.app

# 1. Kill running instance
pkill -9 "$APP_NAME" 2>/dev/null

# 2. Clear UserDefaults (hasSeenWelcome, hotkey bindings, history, etc.)
defaults delete "$APP_ID" 2>/dev/null

# 3. Clear saved window state (NSPersistentUI)
rm -rf ~/Library/Saved\ Application\ State/"$APP_ID".savedState

# 4. Clear caches
rm -rf ~/Library/Caches/"$APP_ID"

# 5. Bounce cfprefsd so the next launch sees fresh UserDefaults
#    (without this, defaults delete may not stick for already-running daemons)
killall cfprefsd 2>/dev/null

# 6. Clear TCC privacy grants
tccutil reset ScreenCapture "$APP_ID" 2>/dev/null
tccutil reset Accessibility "$APP_ID" 2>/dev/null

# 7. Re-register with LaunchServices so the new binary location is known
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APP_PATH"

echo "Reset complete. Launch with: open $APP_PATH"
