#!/usr/bin/env bash

set -e

CMAKE_OSX_ARCHITECTURES="arm64e;arm64"
CMAKE_OSX_SYSROOT="iphoneos"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FFMPEG_MODULES_DIR="$ROOT_DIR/modules/ffmpegkit"
FFMPEG_FRAMEWORKS=(
    "$FFMPEG_MODULES_DIR/ffmpegkit.framework"
    "$FFMPEG_MODULES_DIR/libavcodec.framework"
    "$FFMPEG_MODULES_DIR/libavdevice.framework"
    "$FFMPEG_MODULES_DIR/libavfilter.framework"
    "$FFMPEG_MODULES_DIR/libavformat.framework"
    "$FFMPEG_MODULES_DIR/libavutil.framework"
    "$FFMPEG_MODULES_DIR/libswresample.framework"
    "$FFMPEG_MODULES_DIR/libswscale.framework"
)

ensure_ffmpeg_frameworks() {
    for framework in "${FFMPEG_FRAMEWORKS[@]}"; do
        if [ ! -d "$framework" ]; then
            echo -e "\033[1m\033[0;31mMissing FFmpeg framework: $framework\033[0m"
            echo "Run ./_scinsta_fetch_ffmpegkit.sh first."
            exit 1
        fi
    done
}

inject_ffmpeg_frameworks() {
    local input_ipa="$1"
    local output_ipa="$2"
    local temp_dir
    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/scinsta-ffmpeg-ipa.XXXXXX")"

    unzip -q "$input_ipa" -d "$temp_dir"

    local app_dir
    app_dir="$(find "$temp_dir/Payload" -maxdepth 1 -type d -name "*.app" | head -n 1)"
    if [ -z "$app_dir" ]; then
        echo -e '\033[1m\033[0;31mCould not find Payload/*.app in IPA.\033[0m'
        rm -rf "$temp_dir"
        exit 1
    fi

    mkdir -p "$app_dir/Frameworks"
    for framework in "${FFMPEG_FRAMEWORKS[@]}"; do
        local destination="$app_dir/Frameworks/$(basename "$framework")"
        rm -rf "$destination"
        ditto "$framework" "$destination"
    done

    rm -f "$output_ipa"
    (
        cd "$temp_dir"
        zip -qry "$output_ipa" Payload
    )
    rm -rf "$temp_dir"
}

# Prerequisites
if [ -z "$(ls -A modules/FLEXing)" ]; then
    echo -e '\033[1m\033[0;31mFLEXing submodule not found.\nPlease run the following command to checkout submodules:\n\n\033[0m    git submodule update --init --recursive'
    exit 1
fi

# Building modes
if [ "$1" == "sideload" ];
then

    # Check if building with dev mode
    if [ "$2" == "--dev" ];
    then
        # Cache pre-built FLEX libs
        mkdir -p "packages/cache"
        cp -f ".theos/obj/debug/FLEXing.dylib" "packages/cache/FLEXing.dylib" 2>/dev/null || true
        cp -f ".theos/obj/debug/libflex.dylib" "packages/cache/libflex.dylib" 2>/dev/null || true

        if [[ ! -f "packages/cache/FLEXing.dylib" || ! -f "packages/cache/libflex.dylib" ]]; then
            echo -e '\033[1m\033[0;33mCould not find cached pre-built FLEX libs, building prerequisite binaries\033[0m'
            echo

            ./build.sh sideload --buildonly
            ./build-dev.sh true
            exit
        fi

        MAKEARGS='DEV=1'
        FLEXPATH='packages/cache/FLEXing.dylib packages/cache/libflex.dylib'
        COMPRESSION=0
    else
        # Clear cached FLEX libs
        rm -rf "packages/cache"

        MAKEARGS='SIDELOAD=1'
        FLEXPATH='.theos/obj/debug/FLEXing.dylib .theos/obj/debug/libflex.dylib'
        COMPRESSION=9
    fi

    # Clean build artifacts
    make clean
    rm -rf .theos

    # Check for decrypted instagram ipa
    ipaFiles=($(ls packages/com.burbn.instagram*.ipa 2>/dev/null | sort -V))
    if [ ${#ipaFiles[@]} -eq 0 ]; then
        echo -e '\033[1m\033[0;31m./packages/com.burbn.instagram.ipa not found.\nPlease put a decrypted Instagram IPA in its path.\033[0m'
        exit 1
    fi

    if [ ${#ipaFiles[@]} -gt 1 ]; then
        echo -e '\033[1m\033[0;33mMultiple IPA files found in packages directory. Using the latest one:\033[0m'
        for f in "${ipaFiles[@]}"; do
            echo "  - $(basename "$f")"
        done
        echo
    fi

    ipaFile=$(basename "${ipaFiles[${#ipaFiles[@]}-1]}")

    echo -e '\033[1m\033[32mBuilding SCInsta tweak for sideloading (as IPA)\033[0m'
    make $MAKEARGS

    # Only build libs (for future use in dev build mode)
    if [ "$2" == "--buildonly" ];
    then
        exit
    fi

    SCINSTAPATH=".theos/obj/debug/SCInsta.dylib"
    if [ "$2" == "--devquick" ];
    then
        # Exclude SCInsta.dylib from ipa for livecontainer quick builds
        SCINSTAPATH=""
    fi

    CYAN_FILES=()
    if [ -n "$SCINSTAPATH" ]; then
        CYAN_FILES+=("$SCINSTAPATH")
    fi
    for file in $FLEXPATH; do
        CYAN_FILES+=("$file")
    done
    ensure_ffmpeg_frameworks

    # Create IPA File
    echo -e '\033[1m\033[32mCreating the IPA file...\033[0m'
    rm -f packages/SCInsta-sideloaded.ipa
    cyan -i "packages/${ipaFile}" -o packages/SCInsta-sideloaded.ipa -f "${CYAN_FILES[@]}" -c $COMPRESSION -m 15.0 -du

    echo -e '\033[1m\033[32mManually injecting FFmpeg frameworks...\033[0m'
    inject_ffmpeg_frameworks "packages/SCInsta-sideloaded.ipa" "$ROOT_DIR/packages/SCInsta-sideloaded-with-ffmpeg.ipa"
    mv -f packages/SCInsta-sideloaded-with-ffmpeg.ipa packages/SCInsta-sideloaded.ipa
    
    # Patch IPA for sideloading
    ipapatch --input "packages/SCInsta-sideloaded.ipa" --inplace --noconfirm

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nYou can find the ipa file at: $(pwd)/packages"

elif [ "$1" == "inject-ffmpeg" ];
then
    ipaFiles=($(ls packages/com.burbn.instagram*.ipa 2>/dev/null | sort -V))
    if [ ${#ipaFiles[@]} -eq 0 ]; then
        echo -e '\033[1m\033[0;31m./packages/com.burbn.instagram.ipa not found.\nPlease put a decrypted Instagram IPA in its path.\033[0m'
        exit 1
    fi

    if [ ${#ipaFiles[@]} -gt 1 ]; then
        echo -e '\033[1m\033[0;33mMultiple IPA files found in packages directory. Using the latest one:\033[0m'
        for f in "${ipaFiles[@]}"; do
            echo "  - $(basename "$f")"
        done
        echo
    fi

    ipaFile=$(basename "${ipaFiles[${#ipaFiles[@]}-1]}")

    echo -e '\033[1m\033[32mInjecting FFmpeg frameworks into the base IPA...\033[0m'
    ensure_ffmpeg_frameworks
    inject_ffmpeg_frameworks "packages/${ipaFile}" "$ROOT_DIR/packages/SCInsta-sideloaded.ipa"

    echo -e "\033[1m\033[32mDone.\033[0m\n\nYou can find the ipa file at: $(pwd)/packages"

elif [ "$1" == "rootless" ];
then
    
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e '\033[1m\033[32mBuilding SCInsta tweak for rootless\033[0m'

    export THEOS_PACKAGE_SCHEME=rootless
    make package

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"

elif [ "$1" == "rootful" ];
then

    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e '\033[1m\033[32mBuilding SCInsta tweak for rootful\033[0m'

    unset THEOS_PACKAGE_SCHEME
    make package

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"

else
    echo '+--------------------+'
    echo '|SCInsta Build Script|'
    echo '+--------------------+'
    echo
    echo 'Usage: ./build.sh <sideload|inject-ffmpeg|rootless|rootful>'
    echo
    echo '  sideload      - Build a patched IPA for sideloading'
    echo '  inject-ffmpeg - Inject FFmpeg frameworks into the input IPA only'
    echo '  rootless      - Build a rootless .deb package'
    echo '  rootful       - Build a rootful .deb package'
    exit 1
fi
