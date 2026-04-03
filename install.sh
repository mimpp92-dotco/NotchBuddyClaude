#!/bin/bash
set -e

APP_NAME="NotchBuddy"
APP_PATH="/Applications/$APP_NAME.app"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_URL="http://localhost:31982/hook"
ZIP_URL="https://github.com/mimpp92-dotco/NotchBuddyClaude/releases/latest/download/NotchBuddy-v1.0.0.zip"

# --- 색상 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

# --- 제거 모드 ---
if [ "$1" = "--uninstall" ]; then
    echo "🗑  NotchBuddy 제거 중..."
    pkill -f "$APP_NAME" 2>/dev/null || true
    rm -rf "$APP_PATH"
    # settings.json에서 hooks 제거
    if command -v python3 &>/dev/null && [ -f "$SETTINGS" ]; then
        python3 -c "
import json, sys
try:
    with open('$SETTINGS') as f: s = json.load(f)
    hooks = s.get('hooks', {})
    for e in list(hooks.keys()):
        hooks[e] = [g for g in hooks[e] if not any('localhost:31982' in h.get('command','') for h in g.get('hooks',[]))]
        if not hooks[e]: del hooks[e]
    s['hooks'] = hooks if hooks else s.pop('hooks', None) or {}
    with open('$SETTINGS','w') as f: json.dump(s, f, indent=2, ensure_ascii=False)
except: pass
" 2>/dev/null
    fi
    ok "NotchBuddy 제거 완료"
    exit 0
fi

echo ""
echo "🐾 NotchBuddy Claude 설치"
echo "========================="
echo ""

# --- 1. 환경 확인 ---
echo "📋 환경 확인 중..."

# macOS 확인
if [ "$(uname)" != "Darwin" ]; then
    fail "macOS에서만 실행 가능합니다."
fi

# 아키텍처 확인
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    fail "현재 Apple Silicon(arm64)만 지원합니다. (감지됨: $ARCH)"
fi

# macOS 버전 확인
MACOS_VER=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
if [ "$MAJOR" -lt 12 ]; then
    fail "macOS 12 이상 필요합니다. (현재: $MACOS_VER)"
fi

ok "macOS $MACOS_VER ($ARCH)"

# python3 확인
if ! command -v python3 &>/dev/null; then
    fail "python3이 필요합니다. Xcode Command Line Tools를 설치하세요: xcode-select --install"
fi
ok "python3 사용 가능"

# curl 확인
if ! command -v curl &>/dev/null; then
    fail "curl이 필요합니다."
fi

# --- 2. 다운로드 ---
echo ""
echo "📥 다운로드 중..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

HTTP_CODE=$(curl -sL -w '%{http_code}' "$ZIP_URL" -o "$TMP_DIR/NotchBuddy.zip")
if [ "$HTTP_CODE" != "200" ]; then
    fail "다운로드 실패 (HTTP $HTTP_CODE). URL: $ZIP_URL"
fi

FILE_SIZE=$(wc -c < "$TMP_DIR/NotchBuddy.zip" | tr -d ' ')
if [ "$FILE_SIZE" -lt 100000 ]; then
    fail "다운로드된 파일이 너무 작습니다 (${FILE_SIZE} bytes). 손상된 파일일 수 있습니다."
fi
ok "다운로드 완료 ($(echo "$FILE_SIZE" | awk '{printf "%.1fMB", $1/1048576}'))"

# --- 3. 압축 해제 ---
echo ""
echo "📦 설치 중..."
unzip -qo "$TMP_DIR/NotchBuddy.zip" -d "$TMP_DIR"

if [ ! -d "$TMP_DIR/$APP_NAME.app" ]; then
    fail "압축 해제 실패: $APP_NAME.app을 찾을 수 없습니다."
fi

# 기존 앱 종료 + 제거
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 1
if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
fi

mv "$TMP_DIR/$APP_NAME.app" /Applications/
ok "앱 설치됨: $APP_PATH"

# --- 4. 보안 설정 ---
echo ""
echo "🔒 보안 설정 중..."
xattr -cr "$APP_PATH" 2>/dev/null
codesign --force --deep -s - "$APP_PATH" 2>/dev/null

# 서명 검증
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    ok "코드 서명 완료"
else
    warn "코드 서명 검증 실패 — 실행에 문제가 있을 수 있습니다"
fi

# --- 5. Claude Code hooks 설정 ---
echo ""
echo "🔧 Claude Code 훅 설정 중..."
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
    ok "settings.json 생성됨"
fi

# JSON 유효성 검사
if ! python3 -c "import json; json.load(open('$SETTINGS'))" 2>/dev/null; then
    warn "기존 settings.json이 유효하지 않음 — 백업 후 재생성"
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"
    echo '{}' > "$SETTINGS"
fi

# hooks 설정 (python3)
HOOK_RESULT=$(python3 << 'PYEOF'
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_cmd = "curl -sf -X POST http://localhost:31982/hook -H 'Content-Type: application/json' -d @- --max-time 2 2>/dev/null || true"
events = ["SessionStart", "PreToolUse", "PostToolUse", "Notification", "Stop", "SessionEnd"]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except Exception as e:
    print(f"FAIL:settings.json 읽기 실패: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(settings, dict):
    settings = {}

hooks = settings.get("hooks", {})
if not isinstance(hooks, dict):
    hooks = {}

hook_entry = {"hooks": [{"type": "command", "command": hook_cmd}]}
added = 0

for event in events:
    event_list = hooks.get(event, [])
    if not isinstance(event_list, list):
        event_list = []

    already = False
    for g in event_list:
        if isinstance(g, dict):
            for h in g.get("hooks", []):
                if isinstance(h, dict) and "localhost:31982" in h.get("command", ""):
                    already = True
                    break
        if already:
            break

    if not already:
        event_list.append(hook_entry)
        added += 1
    hooks[event] = event_list

settings["hooks"] = hooks

try:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print(f"OK:{added} events added, {len(events)-added} already existed")
except Exception as e:
    print(f"FAIL:settings.json 저장 실패: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)

if [ $? -eq 0 ]; then
    ok "Claude Code 훅 설정 완료 ($HOOK_RESULT)"
else
    warn "훅 설정 실패 — 수동 설정이 필요할 수 있습니다"
    echo "  자세한 내용: https://github.com/mimpp92-dotco/NotchBuddyClaude#manual-hook-setup"
fi

# hooks 검증
if python3 -c "
import json
with open('$SETTINGS') as f: s = json.load(f)
hooks = s.get('hooks', {})
count = sum(1 for e in ['SessionStart','Stop','SessionEnd']
            if any('localhost:31982' in h.get('command','')
                   for g in hooks.get(e,[])
                   for h in g.get('hooks',[])))
assert count >= 3, f'Only {count}/3 core hooks found'
" 2>/dev/null; then
    ok "훅 검증 통과 (settings.json에 정상 등록)"
else
    warn "훅 검증 실패 — settings.json 내용을 확인하세요"
    echo "  파일 위치: $SETTINGS"
fi

# --- 6. 앱 실행 ---
echo ""
echo "🚀 앱 실행 중..."
open "$APP_PATH"
sleep 2

# 실행 확인
if pgrep -f "$APP_NAME" > /dev/null 2>&1; then
    ok "NotchBuddy 실행 중 (PID: $(pgrep -f "$APP_NAME" | head -1))"
else
    warn "앱이 실행되지 않았습니다."
    echo ""
    echo "  문제 해결:"
    echo "  1. 시스템 설정 > 개인정보 보호 및 보안 > '확인 없이 열기' 클릭"
    echo "  2. 또는 터미널에서: open /Applications/NotchBuddy.app"
    echo "  3. 그래도 안 되면: /Applications/NotchBuddy.app/Contents/MacOS/NotchBuddy"
    echo "     (에러 메시지를 확인할 수 있습니다)"
fi

# --- 완료 ---
echo ""
echo "═══════════════════════════════════════"
echo -e "${GREEN}✅ 설치 완료!${NC}"
echo ""
echo "  사용법: Claude Code를 시작하면 노치에 마스코트가 나타납니다"
echo "  제거:   curl -sL https://raw.githubusercontent.com/mimpp92-dotco/NotchBuddyClaude/main/install.sh | bash -s -- --uninstall"
echo ""
echo "  문제 발생 시 진단:"
echo "    /Applications/NotchBuddy.app/Contents/MacOS/NotchBuddy"
echo "═══════════════════════════════════════"
echo ""
