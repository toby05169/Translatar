// swift-tools-version: 5.9
// Translatar - AI实时翻译耳机应用
// 本文件定义了项目的Swift Package依赖

import PackageDescription

let package = Package(
    name: "Translatar",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Translatar",
            targets: ["Translatar"]
        ),
    ],
    dependencies: [
        // Starscream: WebSocket客户端库，用于连接OpenAI Realtime API
        .package(url: "https://github.com/nicklama/starscream-spm", from: "4.0.8"),
    ],
    targets: [
        .target(
            name: "Translatar",
            dependencies: [
                .product(name: "Starscream", package: "starscream-spm"),
            ]
        ),
    ]
)
