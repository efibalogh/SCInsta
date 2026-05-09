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
            echo "Run ./fetch-ffmpegkit.sh first."
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

build_sideload_fix_library() {
    echo -e '\033[1m\033[32mBuilding SCISideloadFix.dylib...\033[0m'
    make -C "$ROOT_DIR/modules/SCISideloadFix" DEBUG=0 FINALPACKAGE=1
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

select_input_ipa() {
    local ipa_files=("$@")
    local selected_index

    if [ ${#ipa_files[@]} -eq 1 ]; then
        basename "${ipa_files[0]}"
        return 0
    fi

    if [ -t 0 ] && [ -z "${CI:-}" ]; then
        echo -e '\033[1m\033[0;33mMultiple IPA files found in packages directory. Choose one to build:\033[0m' >&2
        local i=1
        for ipa_path in "${ipa_files[@]}"; do
            echo "  [$i] $(basename "$ipa_path")" >&2
            i=$((i + 1))
        done

        while true; do
            printf 'Selection [1-%d]: ' "${#ipa_files[@]}" >&2
            read -r selected_index
            if [[ "$selected_index" =~ ^[0-9]+$ ]] && [ "$selected_index" -ge 1 ] && [ "$selected_index" -le "${#ipa_files[@]}" ]; then
                basename "${ipa_files[$((selected_index - 1))]}"
                return 0
            fi
            echo -e '\033[1m\033[0;31mInvalid selection.\033[0m' >&2
        done
    fi

    echo -e '\033[1m\033[0;33mMultiple IPA files found in packages directory. Non-interactive environment detected; using the latest one:\033[0m' >&2
    for ipa_path in "${ipa_files[@]}"; do
        echo "  - $(basename "$ipa_path")" >&2
    done
    echo >&2
    basename "${ipa_files[${#ipa_files[@]}-1]}"
}

sideload_fix_dylib_path() {
    local path
    for path in \
        "$ROOT_DIR/modules/SCISideloadFix/.theos/obj/SCISideloadFix.dylib" \
        "$ROOT_DIR/modules/SCISideloadFix/.theos/obj/debug/SCISideloadFix.dylib"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
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

# Args: instagram ipa basename without .ipa; globals OPT_* must be set
scinsta_sideload_output_ipa() {
    local ig_base="$1"
    if [ "${OPT_INJECT:-0}" -eq 1 ] && [ "${OPT_FFMPEG:-0}" -eq 1 ] && [ "${OPT_PATCH:-0}" -eq 1 ]; then
        if [ "${OPT_DEV:-0}" -eq 1 ]; then
            if [ "${OPT_FLEX:-0}" -eq 1 ]; then
                echo "SCInsta-dev.ipa"
            else
                echo "SCInsta-dev-no-flex.ipa"
            fi
        else
            if [ "${OPT_FLEX:-0}" -eq 1 ]; then
                echo "SCInsta.ipa"
            else
                echo "SCInsta-no-flex.ipa"
            fi
        fi
        return
    fi
    local parts=()
    [ "${OPT_INJECT:-0}" -eq 1 ] && parts+=(inject)
    [ "${OPT_FFMPEG:-0}" -eq 1 ] && parts+=(ffmpeg)
    [ "${OPT_FLEX:-0}" -eq 1 ] && parts+=(flex)
    [ "${OPT_PATCH:-0}" -eq 1 ] && parts+=(patch)
    [ "${OPT_DEV:-0}" -eq 1 ] && parts+=(dev)
    local joined
    joined=$(IFS=-; echo "${parts[*]}")
    echo "${ig_base}-${joined}.ipa"
}

# Building modes
if [ "$1" == "sideload" ];
then
    shift
    OPT_INJECT=0
    OPT_FFMPEG=0
    OPT_FLEX=0
    OPT_PATCH=0
    OPT_DEV=0
    OPT_BUILDONLY=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --release)
                OPT_INJECT=1
                OPT_FFMPEG=1
                OPT_PATCH=1
                ;;
            --inject) OPT_INJECT=1 ;;
            --ffmpeg) OPT_FFMPEG=1 ;;
            --flex) OPT_FLEX=1 ;;
            --patch) OPT_PATCH=1 ;;
            --dev) OPT_DEV=1 ;;
            --buildonly) OPT_BUILDONLY=1 ;;
            *)
                echo -e "\033[1m\033[0;31mUnknown sideload flag: $1\033[0m"
                echo "Use: ./build.sh sideload [--release|--inject|--ffmpeg|--flex|--patch|--dev|--buildonly] ..."
                exit 1
                ;;
        esac
        shift
    done

    if [ "$OPT_INJECT" -eq 0 ] && [ "$OPT_FFMPEG" -eq 0 ] && [ "$OPT_FLEX" -eq 0 ]; then
        echo -e '\033[1m\033[0;31msideload: specify at least one of --release, --inject, --ffmpeg, --flex\033[0m'
        exit 1
    fi

    MAKEARGS='SIDELOAD=1 DEBUG=0 FINALPACKAGE=1'
    COMPRESSION=9
    if [ "$OPT_DEV" -eq 1 ]; then
        MAKEARGS='DEV=1'
        COMPRESSION=0
    fi

    if [ "$OPT_FLEX" -eq 1 ]; then
        ensure_flexing_submodule
    fi

    if [ "$OPT_INJECT" -eq 1 ]; then
        if [ "$OPT_DEV" -eq 0 ]; then
            rm -rf "packages/cache"
        fi
        make clean
        rm -rf .theos
    fi

    if [ "$OPT_BUILDONLY" -eq 0 ]; then
        ipaFiles=($(ls packages/com.burbn.instagram*.ipa 2>/dev/null | sort -V))
        if [ ${#ipaFiles[@]} -eq 0 ]; then
            echo -e '\033[1m\033[0;31m./packages/com.burbn.instagram.ipa not found.\nPlease put a decrypted Instagram IPA in its path.\033[0m'
            exit 1
        fi

        ipaFile="$(select_input_ipa "${ipaFiles[@]}")"
    fi

    echo -e '\033[1m\033[32mSideload build...\033[0m'
    if [ "$OPT_INJECT" -eq 1 ]; then
        make $MAKEARGS
    fi
    if [ "$OPT_FLEX" -eq 1 ]; then
        build_lazy_flex_library
    fi
    if [ "$OPT_PATCH" -eq 1 ]; then
        build_sideload_fix_library
    fi

    if [ "$OPT_BUILDONLY" -eq 1 ]; then
        echo -e '\033[1m\033[32mBuild-only mode: skipping IPA.\033[0m'
        exit 0
    fi

    SCINSTAPATH=""
    LIBFLEXPATH=""
    SIDELOADFIXPATH=""
    if [ "$OPT_INJECT" -eq 1 ]; then
        SCINSTAPATH="$(theos_dylib_path SCInsta)" || {
            echo -e '\033[1m\033[0;31mCould not find built SCInsta.dylib.\033[0m'
            exit 1
        }
    fi
    if [ "$OPT_FLEX" -eq 1 ]; then
        LIBFLEXPATH="$(theos_dylib_path libFLEX libflex)" || {
            echo -e '\033[1m\033[0;31mCould not find built libFLEX.dylib.\033[0m'
            exit 1
        }
    fi
    if [ "$OPT_PATCH" -eq 1 ]; then
        SIDELOADFIXPATH="$(sideload_fix_dylib_path)" || {
            echo -e '\033[1m\033[0;31mCould not find built SCISideloadFix.dylib.\033[0m'
            exit 1
        }
    fi
    if [ "$OPT_FFMPEG" -eq 1 ]; then
        ensure_ffmpeg_frameworks
    fi

    ig_base="$(basename "$ipaFile" .ipa)"
    OUTPUT_IPA="$(scinsta_sideload_output_ipa "$ig_base")"
    ipa_out="$ROOT_DIR/packages/${OUTPUT_IPA}"
    ipa_ffmpeg_tmp="$ROOT_DIR/packages/.scinsta-build-tmp-ffmpeg.ipa"
    ipa_stage_input="$ROOT_DIR/packages/.scinsta-build-stage-input.ipa"
    ipa_flex_tmp="$ROOT_DIR/packages/.scinsta-build-tmp-flex.ipa"
    rm -f "$ipa_out" "$ipa_ffmpeg_tmp" "$ipa_stage_input" "$ipa_flex_tmp"

    if [ "$OPT_FFMPEG" -eq 1 ]; then
        echo -e '\033[1m\033[32mInjecting FFmpeg frameworks...\033[0m'
        inject_ffmpeg_frameworks "packages/${ipaFile}" "$ipa_ffmpeg_tmp"
        mv -f "$ipa_ffmpeg_tmp" "$ipa_stage_input"
    else
        cp "packages/${ipaFile}" "$ipa_stage_input"
    fi

    if [ "$OPT_FLEX" -eq 1 ]; then
        echo -e '\033[1m\033[32mBundling libFLEX.dylib for lazy loading...\033[0m'
        copy_flex_library_into_ipa "$ipa_stage_input" "$ipa_flex_tmp" "$LIBFLEXPATH"
        mv -f "$ipa_flex_tmp" "$ipa_stage_input"
    fi

    echo -e '\033[1m\033[32mCreating the IPA file...\033[0m'
    if [ "$OPT_INJECT" -eq 1 ]; then
        cyan -i "$ipa_stage_input" -o "$ipa_out" -f "$SCINSTAPATH" -c "$COMPRESSION" -m 15.0 -duq
    else
        cp "$ipa_stage_input" "$ipa_out"
    fi

    rm -f "$ipa_stage_input"

    if [ "$OPT_PATCH" -eq 1 ]; then
        echo -e '\033[1m\033[32mPatching IPA for sideloading...\033[0m'
        ipapatch --input "$ipa_out" --inplace --noconfirm --dylib "$SIDELOADFIXPATH"
    fi

    echo -e "\033[1m\033[32mDone, we hope you enjoy SCInsta!\033[0m\n\nOutput IPA: $ipa_out"

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
    echo 'Usage: ./build.sh <sideload|rootless|rootful>'
    echo
    echo '  sideload   - Build a patched IPA; flags (combine as needed):'
    echo '    --release   equivalent to --inject --fmpeg --patch'
    echo '    --inject    include SCInsta.dylib'
    echo '    --ffmpeg    include FFmpegKit frameworks'
    echo '    --flex      include libFLEX.dylib'
    echo '    --patch     run ipapatch'
    echo '    --dev       DEV=1 build (use e.g. from build-dev.sh)'
    echo '    --buildonly build dylibs only, skip IPA'
    echo '  Example: ./build.sh sideload --release'
    echo '           ./build.sh sideload --release --flex'
    echo '           ./build.sh sideload --ffmpeg              (FFmpeg in IPA only)'
    echo
    echo '  rootless   - Build a rootless .deb package'
    echo '  rootful    - Build a rootful .deb package'
    exit 1
fi
