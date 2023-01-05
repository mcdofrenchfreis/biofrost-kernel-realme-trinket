#!/usr/bin/env bash
# Build Script for Biofrost Kramel
# Copyright (C) 2022-2023 Mar Yvan D.
set -uo pipefail

# Dependency preparation
git clean -fdx
git reset --hard
rm -rf AnyKernel/*.zip
rm -rf AnyKernel/*.img
rm -rf AnyKernel/Image.gz-dtb
git clone --depth=1 https://github.com/mcdofrenchfreis/AnyKernel3.git -b r5x AnyKernel

# Misc Stuff
DATE=$(TZ=Asia/Singapore date +"%Y%m%d-%s")
START=$(date +"%s")

# Directory Variables
KDIR=$(pwd)
TCDIR=/home/biofrost/Development/Compiler/AOSP-clang
GASDIR=/home/biofrost/Development/Compiler/gas
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb

# Kernel name/version Variables
KNAME="Biofrost"
MIN_HEAD=$(git rev-parse HEAD)
VERSION="$(cat version)/$(echo ${MIN_HEAD:0:8})"
export LOCALVERSION="-${KNAME}-$(echo "${VERSION}")"

# GitHub Variables
export COMMIT_HASH=$(git rev-parse --short HEAD)
export REPO_URL="https://github.com/mcdofrenchfreis/biofrost-kernel-realme-trinket"

# Build Information
LINKER=ld.lld
export COMPILER_NAME="$(${TCDIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export LINKER_NAME="$("${TCDIR}"/bin/${LINKER} --version | head -n 1 | sed 's/(compatible with [^)]*)//' | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export KBUILD_BUILD_USER=xevan
export KBUILD_BUILD_HOST=androidist
export DEVICE="Realme 5 Series"
export CODENAME="realme_trinket"

# Zipping Details
export ZIP_NAME="${KNAME}-$(cat version)-$(echo ${MIN_HEAD:0:8}).zip"

# Telegram Stuffs
bot_token="bot5129489057:AAF5o-JfQ1iAUp9Min7Jcr9sHPjTpCaIlA8"
chat_id="-1001736789494"

function sendinfo() {
    curl -s -X POST "https://api.telegram.org/$bot_token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>Laboratory Machine: Build Triggered</b>%0A<b>Build Date: </b><code>$(date +"%Y-%m-%d %H:%M")</code>%0A<b>Device: </b><code>${DEVICE} (${CODENAME})</code>%0A<b>Kernel Version: </b><code>$(make kernelversion 2>/dev/null)</code>%0A<b>Compiler: </b><code>${COMPILER_NAME}</code>%0A<b>Linker: </b><code>${LINKER_NAME}</code>%0A<b>Zip Name: </b><code>${ZIP_NAME}</code>%0A<b>Branch: </b><code>$(git rev-parse --abbrev-ref HEAD)</code><code> (master)</code>%0A<b>Last Commit Details: </b><a href='${REPO_URL}/commit/${COMMIT_HASH}'>${COMMIT_HASH}</a> <code>($(git log --pretty=format:'%s' -1))</code>"
}   
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/$bot_token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds. | <b>Compiled with: ${COMPILER_NAME} + ${LINKER_NAME}.</b>"
}
function finerr() {
    curl -s -X POST "https://api.telegram.org/$bot_token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="Compilation failed, please check build logs for errors."
    exit 1
}
function compile() {
    make O=out ARCH=arm64 biofrost_defconfig
    export PATH="${TCDIR}/bin:${GASDIR}:${PATH}"
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CLANG_TRIPLE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    make -j$(nproc --all) O=out LLVM=1 LLVM-IAS=1 \

    if ! [ -a "$IMAGE" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel

    if ! [ -a "$DTBO" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/dtbo.img AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r ${ZIP_NAME} . -x ".git*" -x "README.md" -x "*.zip"
    cd ..
}
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push