#!/usr/bin/env bash
#
# Build Script for Biofrost Kramel
# Copyright (C) 2022-2023 Mar Yvan D. (xevan)

# Dependency preparation
make clean mrproper
git clean -fdx
git reset --hard
rm -rf AnyKernel/{*.zip,*.img,Image.gz-dtb}
git clone --depth=1 https://github.com/mcdofrenchfreis/AnyKernel3.git -b r5x AnyKernel

# Main Variables
DATE=$(TZ=Asia/Singapore date +"%a %b %d %r %Z %Y")
BUILD_START=$(date +"%s")
TCDIR=/home/biofrost/Development/Compiler/AndroidClang
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb

# Naming Variables
MIN_HEAD=$(git rev-parse HEAD | cut -c 1-7)
export ZIP_NAME="$(cat biofrost-localversion)-${MIN_HEAD}"
export LOCALVERSION="~$(cat biofrost-localversion)"

# GitHub Variables
export COMMIT_HASH=$(git rev-parse --short HEAD)
export BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
export REPO_URL="https://github.com/mcdofrenchfreis/biofrost-kernel-realme-trinket"

# Build Information
export COMPILER_NAME="$(${TCDIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export LINKER_NAME="$("${TCDIR}"/bin/ld.lld --version | head -n 1 | sed 's/(compatible with [^)]*)//' | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export KBUILD_BUILD_USER=xevan
export KBUILD_BUILD_HOST="24MG"
export DEVICE="Realme 5 Series"
export CODENAME="realme_trinket"
export BUILD_TYPE="OBT"
export DISTRO=$(source /etc/os-release && echo "${NAME}")

# Telegram Integration Variables
CI_ID="-1001736789494"
BOT_ID="5129489057:AAF5o-JfQ1iAUp9Min7Jcr9sHPjTpCaIlA8"

function sendinfo() {
  kernel_version=$(make kernelversion 2>/dev/null)
  commit_details=$(git log --pretty=format:'%s' -1)
  message="<b>Laboratory Machine || CI Build Triggered</b>%0A<b>Docker: </b><code>${DISTRO}</code>%0A<b>Build Date: </b><code>${DATE}</code>%0A<b>Device: </b><code>${DEVICE} (${CODENAME})</code>%0A<b>Build Type: </b><code>${BUILD_TYPE}</code>%0A<b>Kernel Version: </b><code>${kernel_version}</code>%0A<b>Compiler: </b><code>${COMPILER_NAME}</code>%0A<b>Linker: </b><code>${LINKER_NAME}</code>%0A<b>Zip Name: </b><code>${ZIP_NAME}</code>%0A<b>Branch: </b><code>${BRANCH_NAME} (head)</code>%0A<b>Top Commit: </b><a href='${REPO_URL}/commit/${COMMIT_HASH}'>${COMMIT_HASH}</a>%0A<code>(${commit_details})</code>"
  curl -s -X POST "https://api.telegram.org/bot${BOT_ID}/sendMessage" \
    -d chat_id="$CI_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$message"
}
function push() {
    ZIP=$(find AnyKernel -maxdepth 1 -name '*.zip' -type f -printf '%T@ %p\n' | sort -n | tail -1 | awk '{print $2}')
    MD5CHECKSUM=$(md5sum "$ZIP" | cut -d' ' -f1)
    curl -F document=@$ZIP "https://api.telegram.org/bot${BOT_ID}/sendDocument" \
        -F chat_id="$CI_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds. | <b>Compiled with ${COMPILER_NAME}</b> | <b>MD5 Checksum: </b><code>${MD5CHECKSUM}</code>."
}
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_ID}/sendMessage" \
        -d chat_id="$CI_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="Compilation failed, please check build logs for errors."
    exit 1
}
function compile() {
    make O=out ARCH=arm64 biofrost_defconfig
    export PATH="${TCDIR}/bin:${PATH}"
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CLANG_TRIPLE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    make -j$(nproc --all) O=out LLVM=1 LLVM-IAS=1

    if ! [ -a "$IMAGE" ] || ! [ -a "$DTBO" ]; then
        finerr
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel
}
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 "$ZIP_NAME".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    cd ..
}

sendinfo
compile
zipping
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))
push
