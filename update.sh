#!/usr/bin/env bash

set -euo pipefail

APP_NAME="cursor-appimage-bin"

API_URL="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"

TMP_DIR="$(mktemp -d)"
cd "$TMP_DIR"


# 获取真实下载地址
REAL_URL=$(curl -sI "$API_URL" | grep -i '^location:' | tail -n1 | awk '{print $2}' | tr -d '\r')

if [[ -z "$REAL_URL" ]]; then
  echo "无法获取下载地址"
  exit 1
fi

FILE_NAME=$(basename "$REAL_URL")

wget -O Cursor.AppImage "$REAL_URL"

chmod +x Cursor.AppImage

# 获取版本
VERSION=$(./Cursor.AppImage --appimage-version 2>/dev/null || true)

if [[ -z "$VERSION" ]]; then
  VERSION=$(strings Cursor.AppImage | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
fi

if [[ -z "$VERSION" ]]; then
  echo "无法识别版本"
  exit 1
fi

SHA256=$(sha256sum Cursor.AppImage | awk '{print $1}')

cd "$GITHUB_WORKSPACE"

cat > PKGBUILD <<EOF
pkgname=cursor-appimage-bin
pkgver=${VERSION}
pkgrel=1
pkgdesc="Cursor AppImage extracted package"
arch=('x86_64')
url="https://www.cursor.com"
license=('custom')
depends=(gtk3 nss alsa-lib xdg-utils)
options=(!strip)
source=(
    "Cursor.AppImage::${REAL_URL}"
)
sha256sums=('${SHA256}')

prepare() {
    chmod +x Cursor.AppImage
    ./Cursor.AppImage --appimage-extract
}

package() {
    install -dm755 "${pkgdir}/opt/cursor"

    cp -a squashfs-root/* "${pkgdir}/opt/cursor/"

    install -dm755 "${pkgdir}/usr/bin"

    ln -sf /opt/cursor/AppRun "${pkgdir}/usr/bin/cursor"

    install -dm755 "${pkgdir}/usr/share/applications"

    cat > "${pkgdir}/usr/share/applications/cursor.desktop" <<DESKTOP
[Desktop Entry]
Name=Cursor
Exec=/usr/bin/cursor
Terminal=false
Type=Application
Categories=Development;
Icon=cursor
DESKTOP
}
EOF

makepkg --printsrcinfo > .SRCINFO


git config user.name "github-actions"
git config user.email "github-actions@github.com"


git add PKGBUILD .SRCINFO

if git diff --cached --quiet; then
  echo "没有更新"
  exit 0
fi


git commit -m "update: ${VERSION}"

git push
