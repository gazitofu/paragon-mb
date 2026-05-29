// swift-tools-version:5.9
import PackageDescription

// PMCore — 코어 로직(Domain/Service/Network/Auth/Store). SwiftUI/AppKit 비의존 → 단위 테스트 가능.
// 앱 쉘(App/)은 별도 Xcode 앱 타깃이 본 패키지를 로컬 의존성으로 사용한다(architecture.md §빌드 형식).
let package = Package(
    name: "PMCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PMCore", targets: ["PMCore"]),
    ],
    targets: [
        .target(name: "PMCore", path: "Sources/PMCore"),
        .testTarget(name: "PMCoreTests", dependencies: ["PMCore"], path: "Tests/PMCoreTests"),
    ]
)
