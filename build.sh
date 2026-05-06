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

inject_ffmpeg_bundle_into_deb() {
    local base_deb="$1"
    local temp_dir
    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/scinsta-ffmpeg-deb.XXXXXX")"

    dpkg-deb -R "$base_deb" "$temp_dir"

    local dylib_dir
    dylib_dir="$(find "$temp_dir" -name "SCInsta.dylib" -exec dirname {} \; | head -n 1)"
    if [ -z "$dylib_dir" ]; then
        rm -rf "$temp_dir"
        echo -e '\033[1m\033[0;31mCould not locate SCInsta.dylib inside package payload.\033[0m'
        exit 1
    fi

    local prefix=""
    if [[ "$dylib_dir" == *"/var/jb/"* ]]; then
        prefix="var/jb/"
    fi

    local bundle_dir="$temp_dir/${prefix}Library/MobileSubstrate/DynamicLibraries/FFmpegKit"
    mkdir -p "$bundle_dir"
    for framework in "${FFMPEG_FRAMEWORKS[@]}"; do
        ditto "$framework" "$bundle_dir/$(basename "$framework")"
    done

    dpkg-deb -b "$temp_dir" "$base_deb" >/dev/null
    rm -rf "$temp_dir"
}

ensure_flexing_submodule() {
    if [ -z "$(ls -A modules/FLEXing 2>/dev/null)" ]; then
        echo -e '\033[1m\033[0;31mFLEXing submodule not found.\nPlease run the following command to checkout submodules:\n\n\033[0m    git submodule update --init --recursive'
        exit 1
    fi
}

build_lazy_flex_library() {
    echo -e '\033[1m\033[32mBuilding lazy libFLEX.dylib...\033[0m'
    make -C "$ROOT_DIR/modules/FLEXing/libflex" clean
    make -C "$ROOT_DIR/modules/FLEXing/libflex" DEBUG=0 FINALPACKAGE=1
}

theos_dylib_path() {
    local name
    local path
    for name in "$@"; do
        for path in \
            ".theos/obj/${name}.dylib" \
            ".theos/obj/debug/${name}.dylib" \
            "modules/FLEXing/libflex/.theos/obj/${name}.dylib" \
            "modules/FLEXing/libflex/.theos/obj/debug/${name}.dylib"; do
            if [ -f "$path" ]; then
                echo "$path"
                return 0
            fi
        done
    done
    return 1
}

copy_flex_library_into_ipa() {
    local input_ipa="$1"
    local output_ipa="$2"
    local libflex_path="$3"
    local temp_dir
    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/scinsta-flex-ipa.XXXXXX")"

    unzip -q "$input_ipa" -d "$temp_dir"

    local app_dir
    app_dir="$(find "$temp_dir/Payload" -maxdepth 1 -type d -name "*.app" | head -n 1)"
    if [ -z "$app_dir" ]; then
        echo -e '\033[1m\033[0;31mCould not find Payload/*.app in IPA.\033[0m'
        rm -rf "$temp_dir"
        exit 1
    fi

    mkdir -p "$app_dir/Frameworks"
    ditto "$libflex_path" "$app_dir/Frameworks/libFLEX.dylib"

    rm -f "$output_ipa"
    (
        cd "$temp_dir"
        zip -qry "$output_ipa" Payload
    )
    rm -rf "$temp_dir"
}

# Building modes
if [ "$1" == "sideload" ];
then

    MODE="${2:-}"
    WITH_FLEX=0
    SCINSTAPATH="SCInsta"
    MAKEARGS='SIDELOAD=1 DEBUG=0 FINALPACKAGE=1'
    COMPRESSION=9
    OUTPUT_IPA="SCInsta-no-flex.ipa"

    case "$MODE" in
        "")
            rm -rf "packages/cache"
            OUTPUT_IPA="SCInsta-no-flex.ipa"
            ;;
        "--dev")
            MAKEARGS='DEV=1'
            COMPRESSION=0
            OUTPUT_IPA="SCInsta-dev-no-flex.ipa"
            ;;
        "--with-flex")
            WITH_FLEX=1
            OUTPUT_IPA="SCInsta.ipa"
            ;;
        "--dev-flex")
            WITH_FLEX=1
            COMPRESSION=0
            OUTPUT_IPA="SCInsta-dev.ipa"
            ;;
        "--devquick")
            MAKEARGS='DEV=1'
            COMPRESSION=0
            SCINSTAPATH=""
            OUTPUT_IPA="SCInsta-devquick.ipa"
            ;;
        "--buildonly")
            OUTPUT_IPA=""
            ;;
        "--buildonly-flex")
            WITH_FLEX=1
            OUTPUT_IPA=""
            ;;
        *)
            echo -e "\033[1m\033[0;31mUnknown sideload option: $MODE\033[0m"
            echo "Use: ./build.sh sideload [--dev|--with-flex|--dev-flex|--devquick|--buildonly|--buildonly-flex]"
            exit 1
            ;;
    esac

    if [ "$WITH_FLEX" -eq 1 ]; then
        ensure_flexing_submodule
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
    if [ "$WITH_FLEX" -eq 1 ]; then
        build_lazy_flex_library
    fi

    # Only build libs (for future use in dev build mode)
    if [ "$MODE" == "--buildonly" ] || [ "$MODE" == "--buildonly-flex" ];
    then
        exit
    fi

    CYAN_FILES=()
    if [ -n "$SCINSTAPATH" ]; then
        SCINSTAPATH="$(theos_dylib_path SCInsta)" || {
            echo -e '\033[1m\033[0;31mCould not find built SCInsta.dylib.\033[0m'
            exit 1
        }
        CYAN_FILES+=("$SCINSTAPATH")
    fi
    if [ "$WITH_FLEX" -eq 1 ]; then
        LIBFLEXPATH="$(theos_dylib_path libFLEX libflex)" || {
            echo -e '\033[1m\033[0;31mCould not find built libFLEX.dylib.\033[0m'
            exit 1
        }
    fi
    ensure_ffmpeg_frameworks

    # Create IPA File
    echo -e '\033[1m\033[32mCreating the IPA file...\033[0m'
    ipa_out="$ROOT_DIR/packages/${OUTPUT_IPA}"
    ipa_ffmpeg_tmp="$ROOT_DIR/packages/.scinsta-build-tmp-ffmpeg.ipa"
    ipa_flex_tmp="$ROOT_DIR/packages/.scinsta-build-tmp-flex.ipa"
    rm -f "$ipa_out" "$ipa_ffmpeg_tmp" "$ipa_flex_tmp"
    cyan -i "packages/${ipaFile}" -o "$ipa_out" -f "${CYAN_FILES[@]}" -c $COMPRESSION -m 15.0 -du

    echo -e '\033[1m\033[32mManually injecting FFmpeg frameworks...\033[0m'
    inject_ffmpeg_frameworks "$ipa_out" "$ipa_ffmpeg_tmp"
    mv -f "$ipa_ffmpeg_tmp" "$ipa_out"

    if [ "$WITH_FLEX" -eq 1 ]; then
        echo -e '\033[1m\033[32mBundling libFLEX.dylib for lazy loading...\033[0m'
        copy_flex_library_into_ipa "$ipa_out" "$ipa_flex_tmp" "$LIBFLEXPATH"
        mv -f "$ipa_flex_tmp" "$ipa_out"
    fi

    # Patch IPA for sideloading
    ipapatch --input "$ipa_out" --inplace --noconfirm

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nOutput IPA: $ipa_out"

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
    ffmpeg_ipa_name="$(basename "$ipaFile" .ipa)-ffmpeg.ipa"

    echo -e '\033[1m\033[32mInjecting FFmpeg frameworks into the base IPA...\033[0m'
    ensure_ffmpeg_frameworks
    inject_ffmpeg_frameworks "packages/${ipaFile}" "$ROOT_DIR/packages/${ffmpeg_ipa_name}"

    echo -e "\033[1m\033[32mDone.\033[0m\n\nOutput IPA: $(pwd)/packages/${ffmpeg_ipa_name}"

elif [ "$1" == "rootless" ];
then
    
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e '\033[1m\033[32mBuilding SCInsta tweak for rootless\033[0m'

    export THEOS_PACKAGE_SCHEME=rootless
    make package

    ensure_ffmpeg_frameworks
    echo -e '\033[1m\033[32mInjecting FFmpeg frameworks bundle into .deb...\033[0m'
    (
        cd packages
        base_deb="$(ls -t *.deb | head -n 1)"
        if [ -z "$base_deb" ]; then
            echo -e '\033[1m\033[0;31mNo .deb package found in packages/.\033[0m'
            exit 1
        fi
        inject_ffmpeg_bundle_into_deb "$base_deb"
    )

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"

elif [ "$1" == "rootful" ];
then

    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e '\033[1m\033[32mBuilding SCInsta tweak for rootful\033[0m'

    unset THEOS_PACKAGE_SCHEME
    make package

    ensure_ffmpeg_frameworks
    echo -e '\033[1m\033[32mInjecting FFmpeg frameworks bundle into .deb...\033[0m'
    (
        cd packages
        base_deb="$(ls -t *.deb | head -n 1)"
        if [ -z "$base_deb" ]; then
            echo -e '\033[1m\033[0;31mNo .deb package found in packages/.\033[0m'
            exit 1
        fi
        inject_ffmpeg_bundle_into_deb "$base_deb"
    )

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nYou can find the deb file at: $(pwd)/packages"

else
    echo '+--------------------+'
    echo '|SCInsta Build Script|'
    echo '+--------------------+'
    echo
    echo 'Usage: ./build.sh <sideload|inject-ffmpeg|rootless|rootful>'
    echo
    echo '  sideload      - Build a patched IPA for sideloading (SCInsta only by default)'
    echo '    --with-flex   - Bundle libFLEX.dylib for lazy loading (output: SCInsta.ipa)'
    echo '    --dev         - Dev IPA without FLEX (SCInsta-dev-no-flex.ipa)'
    echo '    --dev-flex    - Dev IPA with lazy FLEX (SCInsta-dev.ipa)'
    echo '    --devquick    - Dev IPA, tweak dylib only (SCInsta-devquick.ipa)'
    echo '    --buildonly   - Build dylibs only (no IPA)'
    echo '    --buildonly-flex - Build dylibs incl. libFLEX (no IPA)'
    echo '  inject-ffmpeg - Inject FFmpeg frameworks into the input IPA only'
    echo '  rootless      - Build a rootless .deb package'
    echo '  rootful       - Build a rootful .deb package'
    exit 1
fi
