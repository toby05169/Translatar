// swift-tools-version: 5.9
// Translatar - AI实时翻译耳机应用
// 本文件定义了项目的Swift Package依赖
//
// 注意：本项目使用原生URLSessionWebSocketTask进行WebSocket通信，
// 无需第三方WebSocket库依赖

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
        // 无外部依赖 - 使用原生Apple框架
    ],
    targets: [
        .target(
            name: "Translatar",
            dependencies: []
        ),
    ]
)
