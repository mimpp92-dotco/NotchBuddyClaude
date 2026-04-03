#!/bin/bash
set -e

echo "🐾 NotchBuddy Claude 설치 중..."

# 임시 디렉토리
TMP_DIR=$(mktemp -d)
ZIP_URL="https://github.com/mimpp92-dotco/NotchBuddyClaude/releases/latest/download/NotchBuddy-v1.0.0.zip"

# 다운로드
echo "📥 다운로드 중..."
curl -sL "$ZIP_URL" -o "$TMP_DIR/NotchBuddy.zip"

# 압축 해제
echo "📦 압축 해제 중..."
unzip -qo "$TMP_DIR/NotchBuddy.zip" -d "$TMP_DIR"

# 기존 앱 제거
if [ -d "/Applications/NotchBuddy.app" ]; then
    echo "🔄 기존 버전 제거 중..."
    rm -rf "/Applications/NotchBuddy.app"
fi

# Applications로 이동
echo "📂 Applications에 설치 중..."
mv "$TMP_DIR/NotchBuddy.app" /Applications/

# quarantine 속성 제거
xattr -cr /Applications/NotchBuddy.app

# 정리
rm -rf "$TMP_DIR"

# 실행
echo "🚀 NotchBuddy 실행 중..."
open /Applications/NotchBuddy.app

echo ""
echo "✅ 설치 완료! 노치를 확인하세요."
echo "   제거: rm -rf /Applications/NotchBuddy.app"
