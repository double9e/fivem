#!/bin/sh
# Remaining steps from code/tools/ci/docker-builder/proot_prepare.sh after premake install.
set -xe
JOB_SLOTS=${JOB_SLOTS:-4}
GLIBC_VERSION=2.34-r0
arch="$(apk --print-arch)"
cd /tmp
case "${arch##*-}" in
  x86_64)
    curl "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk" \
      -fsSLO --compressed --retry 5 \
      || (echo "error: failed to download: glibc v${GLIBC_VERSION}" && exit 1)
    mv "glibc-${GLIBC_VERSION}.apk" glibc.apk
    curl "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk" \
      -fsSLO --compressed --retry 5 \
      || (echo "error: failed to download: glibc-bin v${GLIBC_VERSION}" && exit 1)
    mv "glibc-bin-${GLIBC_VERSION}.apk" glibc-bin.apk ;;
  *)
    echo "error: unsupported architecture '$arch'"
    exit 1 ;;
esac
apk --no-cache --force-overwrite --allow-untrusted add /tmp/glibc.apk /tmp/glibc-bin.apk
