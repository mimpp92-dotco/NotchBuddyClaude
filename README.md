# NotchBuddy Claude

MacBook 노치에 사는 Claude Code 동반자 앱.

Claude Code로 작업할 때, 노치 옆에 작은 마스코트가 나타나서 현재 세션 상태를 실시간으로 보여줍니다.

## Features

- **실시간 상태 반영** — idle, working, needsInput, done, error, playing 6가지 상태
- **애니메이션** — 상태별 고유 모션, 눈 깜빡임, 말풍선, 파티클 이펙트
- **멀티 세션 추적** — 노치 클릭 시 패널 확장, 모든 활성 세션 한눈에
- **4개 언어** — 한국어, English, 日本語, 中文
- **오프닝 연출** — 앱 시작 시 "Notch Buddy" 텍스트 + 마스코트 등장
- **랜덤 반응** — 대기 중 하품, 깜빡임, 기지개, 놀람 등

## Installation

터미널에 아래 한 줄을 붙여넣으세요:

```bash
curl -sL https://raw.githubusercontent.com/mimpp92-dotco/NotchBuddyClaude/main/install.sh | bash
```

자동으로 다운로드 → 설치 → 실행됩니다.

### 수동 설치

1. [Releases](https://github.com/mimpp92-dotco/NotchBuddyClaude/releases)에서 `NotchBuddy-v*.zip` 다운로드
2. 압축 풀고 `NotchBuddy.app`을 `/Applications`로 이동
3. 터미널에서 `xattr -cr /Applications/NotchBuddy.app` 실행
4. 앱 실행

### 제거

```bash
rm -rf /Applications/NotchBuddy.app
```

## Requirements

- macOS 12 이상 (노치가 있는 MacBook 권장)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)

## How It Works

1. 앱 실행 시 Claude Code hooks를 자동 설정합니다
2. Claude Code 세션이 시작되면 HTTP hook 이벤트를 수신합니다
3. 마스코트가 실시간으로 상태를 반영합니다

| 상태 | 마스코트 동작 |
|------|-------------|
| Idle | 호흡 애니메이션, 좌우 기울임 |
| Working | 바운스 + 미세 회전 |
| Needs Input | 흔들기 + 스케일 펄스 |
| Done | 점프 + 기울임 + 초록 틴트 |
| Error | 주기적 흔들림 + 빨간 틴트 |
| Playing | 좌우 이동 + 점프 |

## Usage

- **클릭** — 패널 확장 (세션 목록 표시)
- **세션 클릭** — 해당 터미널 포커스
- **우클릭** — 언어 변경, 위치 리셋, 종료
- **메뉴바 아이콘** — 동일한 옵션

## Build from Source

```bash
git clone https://github.com/mimpp92-dotco/NotchBuddyClaude.git
cd NotchBuddyClaude
swift build -c release
```

## License

MIT
