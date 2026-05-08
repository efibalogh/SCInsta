#!/usr/bin/env bash

# Set these environment variables to match your device and bundle IDs
# export PYMOBILEDEVICE3_UDID=00000000-0000000000000000
# export LIVECONTAINER_APPID=com.kdt.livecontainer.randomizedaltstoreid
# export DEVLAUNCHER_APPID=com.socuul.scinsta-devlauncher[.randomizedaltstoreid]

set -e

echo 'Note: This script is meant to be used while developing the tweak.'
echo '      LiveContainer / base IPAs: ./build.sh sideload --ffmpeg  (optional: --flex, --patch)'
echo '      Build libFLEX only: ./build.sh sideload --buildonly --flex'
echo

if [ "$1" == "true" ];
then
    ./build.sh sideload --dev --release

else
    # Built tweak and deploy to live container
    make clean
    make DEV=1

    # Change framework locations to @rpath
    install_name_tool -change "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate" \
                              "@rpath/CydiaSubstrate.framework/CydiaSubstrate" \
                              ".theos/obj/debug/SCInsta.dylib" 2>/dev/null || true

    # Kill running process
    pymobiledevice3 developer dvt pkill "LiveContainer" --tunnel $PYMOBILEDEVICE3_UDID

    # Copy only the tweak dylib. The LiveContainer base IPA is expected to already
    # contain the FFmpeg frameworks.
    pymobiledevice3 apps push $LIVECONTAINER_APPID .theos/obj/debug/SCInsta.dylib Documents/Tweaks/SCInsta

    # Launch SCInsta on iPhone
    sleep 1
    pymobiledevice3 developer dvt launch --kill-existing --tunnel $PYMOBILEDEVICE3_UDID $DEVLAUNCHER_APPID
fi
