#!/bin/bash
# PARAGON .dmg 릴리즈 패키징 — 개인용 ad-hoc 배포 (notarization 없음, 백로그 결정 2026-05-30)
# 용법: tools/make-dmg.sh
# 산출: dist/PARAGON-v{MARKETING_VERSION}.dmg (drag-to-/Applications 레이아웃)
# 전제: xcodegen + Xcode CLI, Apple Development 서명(project.yml, Team F29HVM9355)
set -euo pipefail

cd "$(dirname "$0")/.."   # repo root

VERSION=$(grep -m1 -E '^[[:space:]]*MARKETING_VERSION:' project.yml | sed 's/[^0-9.]//g')
[ -n "$VERSION" ] || { echo "✘ project.yml에서 MARKETING_VERSION 파싱 실패"; exit 1; }
APP_NAME="PARAGON-MB"
WORK=$(mktemp -d /tmp/paragon-dmg.XXXXXX)
DDP="$WORK/ddp"
STAGING="$WORK/staging"
LOG="$WORK/build.log"
DIST="dist"

echo "▶ xcodegen generate"
xcodegen generate >/dev/null

echo "▶ Release 빌드 (fresh DerivedData — 캐시 우회)"
if ! xcodebuild -scheme "$APP_NAME" -configuration Release -derivedDataPath "$DDP" build >"$LOG" 2>&1; then
  echo "✘ 빌드 실패 — 로그 마지막 30줄 ($LOG):"
  tail -30 "$LOG"
  exit 1
fi
grep -m1 "BUILD SUCCEEDED" "$LOG"

APP="$DDP/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "✘ .app 산출물 없음: $APP"; exit 1; }

echo "▶ 서명 확인"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Apple Development|TeamIdentifier" || {
  echo "⚠️ Apple Development 서명 미확인 — keychain 신뢰(DR) 영속이 깨질 수 있음"; }

echo "▶ 스테이징 (.app + /Applications 심링크)"
mkdir -p "$STAGING" "$DIST"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="$DIST/PARAGON-v$VERSION.dmg"
echo "▶ hdiutil create → $DMG"
hdiutil create -volname "PARAGON v$VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

echo "✔ 완료: $DMG"
echo "  설치: .dmg 열고 PARAGON-MB.app을 Applications로 드래그 (또는 ditto로 복사)"
echo "  로그인 자동 실행: 설치본 실행 → 메뉴바 ◇ 우클릭 → '로그인 시 자동 실행' 체크"
