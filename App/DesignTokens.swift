import SwiftUI
import PMCore

// design-language.md(Vault design/) §2~5 토큰을 SwiftUI로 번역한 코드 SSOT.
// 색은 시스템 Appearance를 따르는 다크/라이트 동적 쌍(NSColor dynamicProvider). 데이터 3색 부호 잠금(§2.4).

// MARK: - 색 헬퍼

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

private extension Color {
    /// 시스템 Appearance에 따라 라이트/다크 hex를 전환하는 동적 색.
    init(lightHex: UInt32, lightAlpha: CGFloat = 1, darkHex: UInt32, darkAlpha: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(hex: darkHex, alpha: darkAlpha)
                : NSColor(hex: lightHex, alpha: lightAlpha)
        })
    }
}

// MARK: - PMColor (design-language §2)

enum PMColor {
    // §2.2/2.3 Surface
    static let panel       = Color(lightHex: 0xFFFFFF, darkHex: 0x0F2044)  // 패널 컨테이너
    static let header      = Color(lightHex: 0xEFEEE8, darkHex: 0x0F2044)  // 헤더 Sunken / 다크 surface-1
    static let sunken      = Color(lightHex: 0xEFEEE8, darkHex: 0x0F2044)  // 입력창 배경(= header)
    static let hover       = Color(lightHex: 0xFAFAFA, darkHex: 0x142952)  // 행 hover(라이트 중립 — 데이터색 AA)

    // §2.2/2.3 텍스트
    static let textPrimary   = Color(lightHex: 0x0B1729, darkHex: 0xE8EDF5)
    static let textSecondary = Color(lightHex: 0x475569, darkHex: 0x94A3B8)
    static let wordmark      = Color(lightHex: 0x0B1729, darkHex: 0xF5F5F0)

    // §2.2/2.3 보더
    static let border      = Color(lightHex: 0xD6D3C8, darkHex: 0x64748B, darkAlpha: 0.25)
    static let borderMuted = Color(lightHex: 0xE7E5DC, darkHex: 0x64748B, darkAlpha: 0.12)

    // §2.1 브랜드
    static let sapphire = Color(lightHex: 0x3B82F6, darkHex: 0x3B82F6)
    static let midnight = Color(lightHex: 0x0B1729, darkHex: 0x0B1729)

    // §2.4 데이터 3색 — display(텍스트) 변형. ★ 부호 잠금
    static let dataUpText      = Color(lightHex: 0xDC2626, darkHex: 0xF87171)  // 상승 red
    static let dataDownText    = Color(lightHex: 0x2563EB, darkHex: 0x60A5FA)  // 하락 blue
    static let dataNeutralText = Color(lightHex: 0x64748B, darkHex: 0x94A3B8)  // 보합 slate

    // Primary 버튼(CTA·등록): 라이트 Midnight bg / 다크 sapphire bg (§2.3)
    static let primaryButtonBg   = Color(lightHex: 0x0B1729, darkHex: 0x3B82F6)
    static let primaryButtonText = Color(lightHex: 0xFFFFFF, darkHex: 0x0B1729)

    // §2.6 상태 배지·배너
    static let badgeWarning  = Color(lightHex: 0xF59E0B, darkHex: 0xF59E0B)
    static let badgeError    = Color(lightHex: 0xDC2626, darkHex: 0xDC2626)
    static let pearl         = Color(lightHex: 0xF8F7F2, darkHex: 0xF8F7F2)

    static let alertWarningText = Color(lightHex: 0x92400E, darkHex: 0xF59E0B)  // amber-900 / amber
    static let alertErrorText   = Color(lightHex: 0x991B1B, darkHex: 0xF87171)  // red-800 / F87171
    static let alertWarningBg   = Color(lightHex: 0xF59E0B, lightAlpha: 0.10, darkHex: 0xF59E0B, darkAlpha: 0.10)
    static let alertErrorBg     = Color(lightHex: 0xDC2626, lightAlpha: 0.08, darkHex: 0xDC2626, darkAlpha: 0.10)

    // §5 실시간 갱신 하이라이트 tint
    static let highlightUp   = Color(lightHex: 0xDC2626, lightAlpha: 0.12, darkHex: 0xDC2626, darkAlpha: 0.15)
    static let highlightDown = Color(lightHex: 0x2563EB, lightAlpha: 0.12, darkHex: 0x2563EB, darkAlpha: 0.15)

    // 스켈레톤 shimmer(§2.6)
    static let skeletonBase      = Color(lightHex: 0x000000, lightAlpha: 0.06, darkHex: 0xFFFFFF, darkAlpha: 0.06)
    static let skeletonHighlight = Color(lightHex: 0x000000, lightAlpha: 0.10, darkHex: 0xFFFFFF, darkAlpha: 0.12)

    // §2.5 컬러 보석 4면(로고 전용)
    static let gemHighlight = Color(lightHex: 0x7DB7FB, darkHex: 0x7DB7FB)  // TL 수광
    static let gemBase      = Color(lightHex: 0x3B82F6, darkHex: 0x3B82F6)  // TR
    static let gemMidDark   = Color(lightHex: 0x2563EB, darkHex: 0x2563EB)  // BL
    static let gemShadow    = Color(lightHex: 0x1E40AF, darkHex: 0x1E40AF)  // BR
}

// MARK: - PMFont (design-language §3 — tabular-nums 필수)

enum PMFont {
    static let t2          = Font.system(size: 13, weight: .semibold)   // 헤더 라벨/워드마크
    static let name        = Font.system(size: 13, weight: .medium)     // 종목명(t3)
    static let price       = Font.system(size: 12).monospacedDigit()    // 현재가(t4)
    static let changePct   = Font.system(size: 12, weight: .medium).monospacedDigit()
    static let changeAmt   = Font.system(size: 10).monospacedDigit()
    static let caption     = Font.system(size: 11)                      // 갱신시각·캡션·인라인에러(t5)
    static let status      = Font.system(size: 10).monospacedDigit()    // 헤더 상태텍스트·배지
    static let iconPlus    = Font.system(size: 16, weight: .regular)    // "+" 글리프
    static let input       = Font.system(size: 13).monospacedDigit()
    static let button      = Font.system(size: 13, weight: .medium)
}

// MARK: - PMSpace / PMMotion (§4 / §5)

enum PMSpace {
    static let panelX: CGFloat   = 12
    static let rowY: CGFloat     = 6
    static let headerY: CGFloat  = 8
    static let panelWidth: CGFloat = 320
}

enum PMMotion {
    static let highlightDuration: Double = 0.30   // 단방향 fade-out, 깜빡임 금지
    static let viewTransition: Double = 0.18
    static let toastAutoDismiss: Double = 3.0
}

// MARK: - PriceDirection → 표시색 (M4 — 색 매핑은 App 레이어, PMCore는 부호·심볼만)

extension PriceDirection {
    /// 등락률·등락액 텍스트 색(상승 red / 하락 blue / 보합 slate).
    var displayColor: Color {
        switch self {
        case .up: return PMColor.dataUpText
        case .down: return PMColor.dataDownText
        case .flat: return PMColor.dataNeutralText
        }
    }

    /// 현재가 색 — 보합은 중립이 아니라 주 텍스트(§6.2 오너 오버라이드: compact 현재가 등락색, 보합만 primary).
    var priceColor: Color {
        switch self {
        case .up: return PMColor.dataUpText
        case .down: return PMColor.dataDownText
        case .flat: return PMColor.textPrimary
        }
    }

    /// VoiceOver 방향 단어(Q20).
    var spokenWord: String {
        switch self {
        case .up: return "상승"
        case .down: return "하락"
        case .flat: return "보합"
        }
    }
}

// MARK: - 숫자 포맷 (mockup app.js 포팅 — ko-KR 천단위 콤마, U+2212 부호)

enum PMFormat {
    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    /// 현재가 "75,400" (천단위 콤마).
    static func price(_ n: Int) -> String {
        grouping.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// 등락률 "+1.89%" / "−2.14%"(U+2212) / "0.00%".
    static func pct(_ rate: Double, _ direction: PriceDirection) -> String {
        let abs = String(format: "%.2f", Swift.abs(rate))
        switch direction {
        case .up: return "+\(abs)%"
        case .down: return "\u{2212}\(abs)%"
        case .flat: return "0.00%"
        }
    }

    /// 등락액 절대값 "1,400"(부호는 방향심볼이 표현). 보합은 "0".
    static func amountAbs(_ change: Int) -> String {
        price(Swift.abs(change))
    }
}

// MARK: - GemMark (컬러 4면 보석 — 워드마크·빈 상태. §2.5)

/// 4면 패싯 보석(중심 분할 4 삼각형). 그라데이션·외곽선·글로우 금지(§2.5).
/// 좌상단 수광(TL 최명 → BR 최암). StatusBarController.gemIcon()의 컬러 버전.
struct GemMark: View {
    var width: CGFloat = 10
    var height: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let top    = CGPoint(x: w / 2, y: 0)
            let right  = CGPoint(x: w,     y: h / 2)
            let bottom = CGPoint(x: w / 2, y: h)
            let left   = CGPoint(x: 0,     y: h / 2)
            let center = CGPoint(x: w / 2, y: h / 2)

            func facet(_ a: CGPoint, _ b: CGPoint, _ color: Color) {
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                path.addLine(to: center)
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }
            facet(top,   left,   PMColor.gemHighlight)  // TL #7DB7FB
            facet(top,   right,  PMColor.gemBase)        // TR #3B82F6
            facet(left,  bottom, PMColor.gemMidDark)     // BL #2563EB
            facet(right, bottom, PMColor.gemShadow)      // BR #1E40AF
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}
