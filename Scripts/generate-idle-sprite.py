#!/usr/bin/env python3
"""
기본 Idle 상태 픽셀 마스코트 스프라이트를 생성한다.
32x32 픽셀 PNG 이미지를 생성하여 Resources에 저장한다.

사용법:
    python3 Scripts/generate-idle-sprite.py

의존성:
    pip3 install Pillow
"""

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow가 필요합니다: pip3 install Pillow")
    print("스프라이트 생성을 건너뜁니다. 앱은 코드 생성 플레이스홀더를 사용합니다.")
    exit(0)

import os

# 색상 팔레트
TRANSPARENT = (0, 0, 0, 0)
BODY_LIGHT = (200, 180, 255, 255)    # 연보라
BODY_DARK = (160, 140, 220, 255)     # 진보라
HEAD = (220, 200, 255, 255)          # 밝은 보라
BLACK = (40, 40, 40, 255)            # 눈, 입
BLUSH = (255, 160, 180, 128)         # 볼

def create_idle_sprite():
    """잠자는 마스코트 32x32 픽셀 이미지를 생성한다."""
    img = Image.new("RGBA", (32, 32), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    # 몸통 (둥근 사각형 근사)
    draw.rounded_rectangle([8, 4, 24, 22], radius=4, fill=BODY_LIGHT)

    # 머리
    draw.ellipse([7, 14, 25, 30], fill=HEAD)

    # 잠든 눈 (작은 호) — 왼쪽
    draw.arc([11, 21, 15, 25], start=0, end=180, fill=BLACK, width=1)
    # 잠든 눈 — 오른쪽
    draw.arc([17, 21, 21, 25], start=0, end=180, fill=BLACK, width=1)

    # 입 (작은 미소)
    draw.arc([13, 18, 19, 22], start=0, end=180, fill=BLACK, width=1)

    # 볼
    draw.ellipse([9, 20, 13, 23], fill=BLUSH)
    draw.ellipse([19, 20, 23, 23], fill=BLUSH)

    return img

def main():
    output_dir = os.path.join(os.path.dirname(__file__), "..", "Sources", "ClaudeNotchBuddy", "Resources")
    os.makedirs(output_dir, exist_ok=True)

    sprite = create_idle_sprite()
    output_path = os.path.join(output_dir, "idle_01.png")
    sprite.save(output_path)
    print(f"Idle 스프라이트 생성 완료: {output_path}")
    print(f"크기: {sprite.size[0]}x{sprite.size[1]} 픽셀")

if __name__ == "__main__":
    main()
