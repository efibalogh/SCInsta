#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$ROOT_DIR/modules/ffmpegkit"
CACHE_DIR="$ROOT_DIR/.cache/ffmpegkit"
SRC_ROOT="$CACHE_DIR/src"
ARCHIVE_DIR="$CACHE_DIR/archive"
ARCHIVE_FILE="$ARCHIVE_DIR/ffmpeg-kit-source"
SITE_URL="https://arthenica.github.io/ffmpeg-kit/"
MARKER_FILE="$MODULES_DIR/.scinsta-source-build"
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"

FRAMEWORKS=(
  ffmpegkit
  libavcodec
  libavdevice
  libavfilter
  libavformat
  libavutil
  libswresample
  libswscale
)

patch_framework_rpaths() {
  local framework_dir="$1"
  local framework
  local binary

  for framework in "${FRAMEWORKS[@]}"; do
    binary="$framework_dir/$framework.framework/$framework"
    [[ -f "$binary" ]] || continue
    install_name_tool -add_rpath "@loader_path/.." "$binary" 2>/dev/null || true
  done
}

BUILD_ARGS=(
  --enable-gpl
  --enable-dav1d
  --enable-x264
  --enable-ios-videotoolbox
  --enable-ios-audiotoolbox
  --enable-ios-avfoundation
  --enable-ios-libiconv
  --enable-ios-zlib
  --enable-ios-bzip2
  --xcframework
  --disable-arm64-simulator
  --disable-x86-64
  --disable-arm64-mac-catalyst
  --disable-x86-64-mac-catalyst
)

REQUIRED_TOOLS=(
  autoconf
  automake
  cmake
  curl
  git
  libtool
  make
  meson
  nasm
  ninja
  pkg-config
  wget
  xcodebuild
  xcrun
  yasm
)

usage() {
  cat <<'EOF'
Usage: ./_scinsta_fetch_ffmpegkit.sh [--force]

Builds iOS FFmpegKit frameworks from the archived Arthenica source archive and
installs the ios-arm64 slices into modules/ffmpegkit.
EOF
}

check_prerequisites() {
  local missing=()
  local tool

  for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  echo "[SCInsta] ERROR: Missing build tools required by ffmpeg-kit:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo >&2
  echo "[SCInsta] Install them with Homebrew, then rerun:" >&2
  echo "  brew install autoconf automake cmake libtool meson nasm ninja pkgconf wget yasm" >&2
  echo >&2
  echo "[SCInsta] If Homebrew tools are installed but not visible, ensure your shell exports:" >&2
  echo "  export PATH=\"$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:\$PATH\"" >&2
  exit 1
}

have_complete_install() {
  local expected_args current_args
  [[ -f "$MARKER_FILE" ]] || return 1
  for framework in "${FRAMEWORKS[@]}"; do
    [[ -f "$MODULES_DIR/$framework.framework/$framework" ]] || return 1
  done
  expected_args="${BUILD_ARGS[*]}"
  current_args="$(sed -n 's/^build_args=//p' "$MARKER_FILE" 2>/dev/null || true)"
  [[ "$current_args" == "$expected_args" ]] || return 1
}

fetch_site_archive() {
  local page archive_url

  mkdir -p "$ARCHIVE_DIR"
  page="$(mktemp)"
  trap 'rm -f "$page"' RETURN

  curl -fsSL "$SITE_URL" -o "$page"

  archive_url="$(
    grep -Eo 'https://github\.com/arthenica/ffmpeg-kit(/archive/refs/heads/[^"]+\.(zip|tar\.gz)|/zipball/[^"]+|/tarball/[^"]+)' "$page" \
      | head -n 1
  )"

  if [[ -z "$archive_url" ]]; then
    archive_url="https://github.com/arthenica/ffmpeg-kit/archive/refs/heads/main.zip"
  fi

  case "$archive_url" in
    *.tar.gz|*/tarball/*)
      ARCHIVE_FILE="${ARCHIVE_FILE}.tar.gz"
      ;;
    *)
      ARCHIVE_FILE="${ARCHIVE_FILE}.zip"
      ;;
  esac

  curl -fL "$archive_url" -o "$ARCHIVE_FILE"
  printf '%s\n' "$archive_url" > "$ARCHIVE_DIR/source-url.txt"
}

extract_source() {
  rm -rf "$SRC_ROOT"
  mkdir -p "$SRC_ROOT"

  case "$ARCHIVE_FILE" in
    *.tar.gz)
      tar -xzf "$ARCHIVE_FILE" -C "$SRC_ROOT"
      ;;
    *.zip)
      unzip -q "$ARCHIVE_FILE" -d "$SRC_ROOT"
      ;;
    *)
      echo "[SCInsta] ERROR: Unsupported archive format: $ARCHIVE_FILE" >&2
      exit 1
      ;;
  esac
}

source_dir() {
  find "$SRC_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1
}

build_output_ready() {
  local src_dir="$1"
  [[ -d "$src_dir/prebuilt/bundle-apple-xcframework-ios" ]]
}

build_from_source() {
  local src_dir="$1"
  (
    cd "$src_dir"
    ./ios.sh "${BUILD_ARGS[@]}"
  )
}

install_frameworks() {
  local src_dir="$1"
  local xcfw name slice

  mkdir -p "$MODULES_DIR"
  rm -rf "$MODULES_DIR"/*.framework "$MODULES_DIR"/.DS_Store

  for xcfw in "$src_dir"/prebuilt/bundle-apple-xcframework-ios/*.xcframework; do
    [[ -d "$xcfw" ]] || continue
    name="$(basename "$xcfw" .xcframework)"
    slice="$(
      find "$xcfw" -maxdepth 1 -type d \( -name "ios-arm64" -o -name "ios-arm64_*" \) \
        | sort \
        | head -n 1
    )"
    if [[ -z "$slice" || ! -d "$slice/$name.framework" ]]; then
      echo "[SCInsta] ERROR: Missing ios-arm64 slice for $name in $xcfw" >&2
      exit 1
    fi
    cp -R "$slice/$name.framework" "$MODULES_DIR/"
  done

  patch_framework_rpaths "$MODULES_DIR"

  cat > "$MARKER_FILE" <<EOF
site_url=$SITE_URL
archive_url=$(cat "$ARCHIVE_DIR/source-url.txt" 2>/dev/null || echo unknown)
build_args=${BUILD_ARGS[*]}
EOF
}

force=0
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi
if [[ $# -eq 1 ]]; then
  case "$1" in
    --force) force=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
fi

if [[ "$force" -eq 0 ]] && have_complete_install; then
  echo "[SCInsta] FFmpegKit frameworks already prepared."
  exit 0
fi

check_prerequisites

mkdir -p "$CACHE_DIR"

if [[ "$force" -eq 1 ]]; then
  rm -rf "$SRC_ROOT" "$ARCHIVE_DIR"
fi

if [[ ! -f "$ARCHIVE_FILE.zip" && ! -f "$ARCHIVE_FILE.tar.gz" ]]; then
  fetch_site_archive
else
  if [[ -f "$ARCHIVE_FILE.zip" ]]; then
    ARCHIVE_FILE="${ARCHIVE_FILE}.zip"
  else
    ARCHIVE_FILE="${ARCHIVE_FILE}.tar.gz"
  fi
fi

extract_source
src_dir="$(source_dir)"
if [[ -z "$src_dir" || ! -d "$src_dir" ]]; then
  echo "[SCInsta] ERROR: Could not locate extracted ffmpeg-kit source directory." >&2
  exit 1
fi

if [[ "$force" -eq 1 ]] || ! build_output_ready "$src_dir"; then
  echo "[SCInsta] Building FFmpegKit from source..."
  build_from_source "$src_dir"
fi

install_frameworks "$src_dir"
echo "[SCInsta] FFmpegKit frameworks installed into modules/ffmpegkit."
