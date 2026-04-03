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

# quarantine 속성 제거 + 코드 재서명
xattr -cr /Applications/NotchBuddy.app
codesign --force --deep -s - /Applications/NotchBuddy.app 2>/dev/null

# 정리
rm -rf "$TMP_DIR"

# Claude Code hooks 설정
echo "🔧 Claude Code 훅 설정 중..."
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
mkdir -p "$CLAUDE_DIR"

HOOK_CMD='curl -sf -X POST http://localhost:31982/hook -H '\''Content-Type: application/json'\'' -d @- --max-time 2 2>/dev/null || true'

# settings.json이 없거나 hooks가 없으면 새로 생성
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

# python3으로 안전하게 JSON 병합 (jq 없이)
python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_cmd = "curl -sf -X POST http://localhost:31982/hook -H 'Content-Type: application/json' -d @- --max-time 2 2>/dev/null || true"
events = ["SessionStart", "PreToolUse", "PostToolUse", "Notification", "Stop", "SessionEnd"]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    settings = {}

hooks = settings.get("hooks", {})

hook_entry = {"hooks": [{"type": "command", "command": hook_cmd}]}

for event in events:
    event_list = hooks.get(event, [])
    # 이미 NotchBuddy 훅이 있는지 확인
    already = any(
        any("localhost:31982" in h.get("command", "") for h in g.get("hooks", []))
        for g in event_list if isinstance(g, dict)
    )
    if not already:
        event_list.append(hook_entry)
    hooks[event] = event_list

settings["hooks"] = hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("  hooks 설정 완료")
PYEOF

# 실행
echo "🚀 NotchBuddy 실행 중..."
open /Applications/NotchBuddy.app

echo ""
echo "✅ 설치 완료! 노치를 확인하세요."
echo "   제거하려면: curl -sL https://raw.githubusercontent.com/mimpp92-dotco/NotchBuddyClaude/main/install.sh | bash -s -- --uninstall"
echo "   또는: rm -rf /Applications/NotchBuddy.app"
