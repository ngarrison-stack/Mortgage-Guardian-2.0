#!/bin/sh
set -e
set -o pipefail

function on_error {
  echo "${0}:$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR

if [ -z ${FRAMEWORKS_FOLDER_PATH+x} ]; then
  # If FRAMEWORKS_FOLDER_PATH is not set, then there's nowhere for us to copy
  # frameworks to, so exit 0 (signalling the script phase was successful).
  exit 0
fi

echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

COCOAPODS_PARALLEL_CODE_SIGN="${COCOAPODS_PARALLEL_CODE_SIGN:-false}"
SWIFT_STDLIB_PATH="${TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"
BCSYMBOLMAP_DIR="BCSymbolMaps"


# This protects against multiple targets copying the same framework dependency at the same time. The solution
# was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")

# Copies and strips a vendored framework
install_framework()
{
  local framework_source=""

  # Check if the argument is already a full path to an existing framework
  if [ -e "$1" ]; then
    framework_source="$1"
  # Check relative path from BUILT_PRODUCTS_DIR
  elif [ -e "${BUILT_PRODUCTS_DIR}/$1" ]; then
    framework_source="${BUILT_PRODUCTS_DIR}/$1"
  # Check basename in BUILT_PRODUCTS_DIR
  elif [ -e "${BUILT_PRODUCTS_DIR}/$(basename "$1")" ]; then
    framework_source="${BUILT_PRODUCTS_DIR}/$(basename "$1")"
  else
    echo "Error: Framework not found at any expected location for: $1"
    echo "Checked locations:"
    echo "  $1"
    echo "  ${BUILT_PRODUCTS_DIR}/$1"
    echo "  ${BUILT_PRODUCTS_DIR}/$(basename "$1")"
    return 1
  fi

  local destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

  if [ -L "${framework_source}" ]; then
    echo "Symlinked..."
    local link_target="$(readlink "${framework_source}")"
    # If it's a relative path, resolve it from the symlink's directory
    if [[ "${link_target}" != /* ]]; then
      framework_source="$(dirname "${framework_source}")/${link_target}"
    else
      framework_source="${link_target}"
    fi
  fi

  if [ -d "${framework_source}/${BCSYMBOLMAP_DIR}" ]; then
    # Locate and install any .bcsymbolmaps if present, and remove them from the .framework before the framework is copied
    find "${framework_source}/${BCSYMBOLMAP_DIR}" -name "*.bcsymbolmap"|while read f; do
      echo "Installing $f"
      install_bcsymbolmap "$f" "$destination"
      rm "$f"
    done
    rmdir "${framework_source}/${BCSYMBOLMAP_DIR}"
  fi

  # Use cp instead of rsync to avoid sandbox issues
  if [ -z "${framework_source}" ]; then
    echo "Error: framework_source is empty, cannot copy framework"
    return 1
  fi

  echo "cp -R \"${framework_source}\" \"${destination}\""
  cp -R "${framework_source}" "${destination}"

  # Remove unwanted files after copying
  rm -rf "${destination}/$(basename "${framework_source}")/Headers" 2>/dev/null || true
  rm -rf "${destination}/$(basename "${framework_source}")/PrivateHeaders" 2>/dev/null || true
  rm -rf "${destination}/$(basename "${framework_source}")/Modules" 2>/dev/null || true

  local basename
  basename="$(basename -s .framework "$1")"
  binary="${destination}/${basename}.framework/${basename}"

  if ! [ -r "$binary" ]; then
    binary="${destination}/${basename}"
  elif [ -L "${binary}" ]; then
    echo "Destination binary is symlinked..."
    dirname="$(dirname "${binary}")"
    binary="${dirname}/$(readlink "${binary}")"
  fi

  # Strip invalid architectures so "fat" simulator / device frameworks work on device
  if [[ "$(file "$binary")" == *"dynamically linked shared library"* ]]; then
    strip_invalid_archs "$binary"
  fi

  # Resign the code if required by the build settings to avoid unstable apps
  code_sign_if_enabled "${destination}/$(basename "$1")"

  # Embed linked Swift runtime libraries. No longer necessary as of Xcode 7.
  if [ "${XCODE_VERSION_MAJOR}" -lt 7 ]; then
    local swift_runtime_libs
    swift_runtime_libs=$(xcrun otool -LX "$binary" | grep --color=never @rpath/libswift | sed -E s/@rpath\\/\(.+dylib\).*/\\1/g | uniq -u)
    for lib in $swift_runtime_libs; do
      echo "rsync -auv \"${SWIFT_STDLIB_PATH}/${lib}\" \"${destination}\""
      rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"
      code_sign_if_enabled "${destination}/${lib}"
    done
  fi
}
# Copies and strips a vendored dSYM
install_dsym() {
  local dsym_source="$1"
  warn_missing_arch=${2:-true}
  if [ -r "$dsym_source" ]; then
    # Copy the dSYM into the targets temp dir.
    echo "cp -R \"${dsym_source}\" \"${DERIVED_FILES_DIR}\""
    cp -R "${dsym_source}" "${DERIVED_FILES_DIR}"

    local basename
    basename="$(basename -s .dSYM "$dsym_source")"
    binary_name="$(ls "$dsym_source/Contents/Resources/DWARF")"
    binary="${DERIVED_FILES_DIR}/${basename}.dSYM/Contents/Resources/DWARF/${binary_name}"

    # Strip invalid architectures from the dSYM.
    if [[ "$(file "$binary")" == *"Mach-O "*"dSYM companion"* ]]; then
      strip_invalid_archs "$binary" "$warn_missing_arch"
    fi
    if [[ $STRIP_BINARY_RETVAL == 0 ]]; then
      # Move the stripped file into its final destination.
      echo "cp -R \"${DERIVED_FILES_DIR}/${basename}.dSYM\" \"${DWARF_DSYM_FOLDER_PATH}\""
      cp -R "${DERIVED_FILES_DIR}/${basename}.dSYM" "${DWARF_DSYM_FOLDER_PATH}"
    else
      # The dSYM was not stripped at all, in this case touch a fake folder so the input/output paths from Xcode do not reexecute this script because the file is missing.
      mkdir -p "${DWARF_DSYM_FOLDER_PATH}"
      touch "${DWARF_DSYM_FOLDER_PATH}/${basename}.dSYM"
    fi
  fi
}

# Used as a return value for each invocation of `strip_invalid_archs` function.
STRIP_BINARY_RETVAL=0

# Strip invalid architectures
strip_invalid_archs() {
  binary="$1"
  warn_missing_arch=${2:-true}
  # Get architectures for current target binary
  binary_archs="$(lipo -info "$binary" | rev | cut -d ':' -f1 | awk '{$1=$1;print}' | rev)"
  # Intersect them with the architectures we are building for
  intersected_archs="$(echo ${ARCHS[@]} ${binary_archs[@]} | tr ' ' '\n' | sort | uniq -d)"
  # If there are no archs supported by this binary then warn the user
  if [[ -z "$intersected_archs" ]]; then
    if [[ "$warn_missing_arch" == "true" ]]; then
      echo "warning: [CP] Vendored binary '$binary' contains architectures ($binary_archs) none of which match the current build architectures ($ARCHS)."
    fi
    STRIP_BINARY_RETVAL=1
    return
  fi
  stripped=""
  for arch in $binary_archs; do
    if ! [[ "${ARCHS}" == *"$arch"* ]]; then
      # Strip non-valid architectures in-place
      lipo -remove "$arch" -output "$binary" "$binary"
      stripped="$stripped $arch"
    fi
  done
  if [[ "$stripped" ]]; then
    echo "Stripped $binary of architectures:$stripped"
  fi
  STRIP_BINARY_RETVAL=0
}

# Copies the bcsymbolmap files of a vendored framework
install_bcsymbolmap() {
    local bcsymbolmap_path="$1"
    local destination="${BUILT_PRODUCTS_DIR}"
    echo "cp \"${bcsymbolmap_path}\" \"${destination}\""
    cp "${bcsymbolmap_path}" "${destination}"
}

# Signs a framework with the provided identity
code_sign_if_enabled() {
  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" -a "${CODE_SIGNING_REQUIRED:-}" != "NO" -a "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
    # Use the current code_sign_identity
    echo "Code Signing $1 with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    local code_sign_cmd="/usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS:-} --preserve-metadata=identifier,entitlements '$1'"

    if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
      code_sign_cmd="$code_sign_cmd &"
    fi
    echo "$code_sign_cmd"
    eval "$code_sign_cmd"
  fi
}

if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_framework "${BUILT_PRODUCTS_DIR}/Alamofire/Alamofire.framework"
  install_framework "${BUILT_PRODUCTS_DIR}/KeychainAccess/KeychainAccess.framework"
  install_framework "${PODS_XCFRAMEWORKS_BUILD_DIR}/Plaid/LinkKit.framework"
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_framework "${BUILT_PRODUCTS_DIR}/Alamofire/Alamofire.framework"
  install_framework "${BUILT_PRODUCTS_DIR}/KeychainAccess/KeychainAccess.framework"
  install_framework "${PODS_XCFRAMEWORKS_BUILD_DIR}/Plaid/LinkKit.framework"
fi
if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
  wait
fi
