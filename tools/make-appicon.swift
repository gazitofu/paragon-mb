#!/usr/bin/swift
// PARAGON 앱 아이콘 생성 — 디자인 안 SSOT: Vault design/brand-design-plan.md §4.3 (+ §2.5 보석 팔레트)
// 용법: swift tools/make-appicon.swift   (repo root에서)
// 산출: App/Assets.xcassets/AppIcon.appiconset/ (macOS 10종 PNG + Contents.json)
//
// 1024 기준 지오메트리(외부 작업용 디자인 안 paragon-mb_icon.md와 동일):
//   - 라운디드 스퀘어 824×824 중앙(마진 100px), radius 165px(변의 20%), Midnight #0B1729 플랫
//   - 보석: 마름모 10:14, 높이 494px(스퀘어의 60%), 중심점 4-삼각형 facet
//   - TL #7DB7FB(수광 최명) / TR #3B82F6(기준) / BL #2563EB / BR #1E40AF(그림자 최암)
//   - 면 구분선·그라데이션·글로우 없음. facet 이음새 AA 헤어라인 방지로 베이스 마름모(#2563EB) 선깔기.

import AppKit

func srgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let midnight = srgb(0x0B1729)
let gemTL = srgb(0x7DB7FB), gemTR = srgb(0x3B82F6)
let gemBL = srgb(0x2563EB), gemBR = srgb(0x1E40AF)

/// px 변 정사각 캔버스에 1024 기준 지오메트리를 비례 렌더 (CG 좌표 y-up).
func render(px: Int) -> Data {
    let s = CGFloat(px) / 1024
    guard let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("CGContext 생성 실패 (\(px)px)") }
    ctx.setShouldAntialias(true)

    // 라운디드 스퀘어 (배경 투명 마진 각 변 100px)
    let square = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let radius = 165 * s
    ctx.addPath(CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(midnight)
    ctx.fillPath()

    // 보석 — 마름모 10:14, 높이 = 스퀘어의 60%
    let gh = 824 * 0.6 * s
    let gw = gh * 10 / 14
    let cx = 512 * s, cy = 512 * s
    let top = CGPoint(x: cx, y: cy + gh / 2)
    let right = CGPoint(x: cx + gw / 2, y: cy)
    let bottom = CGPoint(x: cx, y: cy - gh / 2)
    let left = CGPoint(x: cx - gw / 2, y: cy)
    let center = CGPoint(x: cx, y: cy)

    func fill(_ pts: [CGPoint], _ color: CGColor) {
        ctx.beginPath()
        ctx.addLines(between: pts)
        ctx.closePath()
        ctx.setFillColor(color)
        ctx.fillPath()
    }
    fill([top, right, bottom, left], gemBL)          // 베이스 선깔기 — facet 이음새 헤어라인 방지
    fill([top, left, center], gemTL)                 // TL 수광 최명
    fill([top, right, center], gemTR)                // TR 기준
    fill([left, bottom, center], gemBL)              // BL
    fill([right, bottom, center], gemBR)             // BR 그림자 최암

    guard let cg = ctx.makeImage(),
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    else { fatalError("PNG 인코딩 실패 (\(px)px)") }
    return png
}

// macOS AppIcon 10종
let outDir = "App/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
try #"{"info":{"author":"xcode","version":1}}"#
    .write(toFile: "App/Assets.xcassets/Contents.json", atomically: true, encoding: .utf8)

let specs: [(size: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                                        (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [String] = []
for (size, scale) in specs {
    let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try render(px: size * scale).write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    images.append(#"{"size":"\#(size)x\#(size)","idiom":"mac","filename":"\#(name)","scale":"\#(scale)x"}"#)
    print("✔ \(name) (\(size * scale)px)")
}
let contents = #"{"images":[\#(images.joined(separator: ","))],"info":{"author":"xcode","version":1}}"#
try contents.write(toFile: "\(outDir)/Contents.json", atomically: true, encoding: .utf8)
print("✔ Contents.json — 완료: \(outDir)")
