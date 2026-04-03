import SpriteKit

/// 스프라이트 시트에서 상태별 프레임 텍스처를 추출한다.
/// 균일 그리드 방식: 6행(상태) × 8열(프레임).
enum SpriteSheetLoader {

    private static let columns = 16
    private static let stateOrder: [MascotState] = [
        .idle, .working, .needsInput, .done, .error, .playing
    ]

    /// 상태별 개별 PNG에서 애니메이션 프레임 텍스처를 로드한다.
    static func loadFrames() -> [MascotState: [SKTexture]]? {
        let fileMap: [(MascotState, String)] = [
            (.idle, "spritecat_idle"),
            (.working, "spritecat_working"),
            (.needsInput, "spritecat_needsinput"),
            (.done, "spritecat_done"),
            (.error, "spritecat_error"),
            (.playing, "spritecat_playing"),
        ]

        var result: [MascotState: [SKTexture]] = [:]

        for (state, filename) in fileMap {
            guard let texture = loadRowTexture(named: filename) else {
                print("[SpriteSheetLoader] \(filename).png 로드 실패")
                continue
            }

            let frameW = 1.0 / CGFloat(columns)
            var textures: [SKTexture] = []

            for col in 0..<columns {
                let x = CGFloat(col) * frameW
                let rect = CGRect(x: x, y: 0, width: frameW, height: 1.0)
                let frameTex = SKTexture(rect: rect, in: texture)
                frameTex.filteringMode = .nearest
                textures.append(frameTex)
            }

            result[state] = textures
        }

        return result.isEmpty ? nil : result
    }

    /// 첫 번째 idle 프레임을 정적 텍스처로 반환한다.
    static func loadStaticTexture() -> SKTexture? {
        guard let texture = loadRowTexture(named: "spritecat_idle") else { return nil }
        let frameW = 1.0 / CGFloat(columns)
        let rect = CGRect(x: 0, y: 0, width: frameW, height: 1.0)
        let tex = SKTexture(rect: rect, in: texture)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Private

    private static func loadRowTexture(named name: String) -> SKTexture? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else {
            print("[SpriteSheetLoader] \(name).png not found in bundle")
            return nil
        }
        guard let image = NSImage(contentsOf: url),
              let cleaned = removeCheckerboard(from: image) else { return nil }
        let texture = SKTexture(image: cleaned)
        texture.filteringMode = .nearest
        return texture
    }

    /// 체크무늬 배경을 투명으로 교체하고, 가장자리 밝은 아티팩트를 정리한다.
    private static func removeCheckerboard(from image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        let w = bitmap.pixelsWide
        let h = bitmap.pixelsHigh

        guard let newRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: w * 4,
            bitsPerPixel: 32
        ), let dest = newRep.bitmapData else { return nil }

        guard let src = bitmap.bitmapData else { return nil }
        let srcSPP = bitmap.samplesPerPixel
        let srcBPR = bitmap.bytesPerRow
        let bpr = newRep.bytesPerRow

        // 1차 패스: 체크무늬 제거
        for y in 0..<h {
            for x in 0..<w {
                let srcOff = y * srcBPR + x * srcSPP
                let dstOff = y * bpr + x * 4

                let r = src[srcOff]
                let g = src[srcOff + 1]
                let b = src[srcOff + 2]
                let a = srcSPP >= 4 ? src[srcOff + 3] : 255

                // 체크무늬: R≈G≈B이고 밝은 색 (>160, 더 넓은 범위)
                let isGray = abs(Int(r) - Int(g)) < 15
                    && abs(Int(g) - Int(b)) < 15
                    && r > 160

                if isGray {
                    dest[dstOff] = 0; dest[dstOff+1] = 0
                    dest[dstOff+2] = 0; dest[dstOff+3] = 0
                } else {
                    dest[dstOff] = r; dest[dstOff+1] = g
                    dest[dstOff+2] = b; dest[dstOff+3] = a
                }
            }
        }

        // 2차 패스: 투명 픽셀에 인접한 밝은 픽셀 제거 (흰색 아티팩트 정리)
        // dest를 복사해서 읽기용으로 사용
        let bufSize = h * bpr
        let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        readBuf.initialize(from: dest, count: bufSize)
        defer { readBuf.deallocate() }

        for y in 1..<(h-1) {
            for x in 1..<(w-1) {
                let off = y * bpr + x * 4
                let a = readBuf[off + 3]
                guard a > 0 else { continue }  // 이미 투명이면 스킵

                let r = readBuf[off]
                let g = readBuf[off + 1]
                let b = readBuf[off + 2]

                // 밝은 픽셀인지 (R>140, G>140, B>140, 회색조)
                let isBright = r > 140 && g > 140 && b > 140
                    && abs(Int(r) - Int(g)) < 20
                    && abs(Int(g) - Int(b)) < 20
                guard isBright else { continue }

                // 4방향 이웃 중 투명 픽셀이 있으면 제거
                let neighbors = [
                    (y-1) * bpr + x * 4,
                    (y+1) * bpr + x * 4,
                    y * bpr + (x-1) * 4,
                    y * bpr + (x+1) * 4,
                ]
                let hasTransparentNeighbor = neighbors.contains { readBuf[$0 + 3] == 0 }

                if hasTransparentNeighbor {
                    dest[off] = 0; dest[off+1] = 0
                    dest[off+2] = 0; dest[off+3] = 0
                }
            }
        }

        let result = NSImage(size: NSSize(width: w, height: h))
        result.addRepresentation(newRep)
        return result
    }
}
