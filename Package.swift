// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "B2MAnalyticsSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "B2MAnalyticsSDK", targets: ["B2MAnalyticsSDK"])
    ],
    targets: [
        .binaryTarget(
            name: "B2MAnalyticsSDK",
            url: "https://github.com/B2M-Team/b2metric-ios-sdk/releases/download/2.0.0/B2MAnalyticsSDK.xcframework.zip",
            checksum: "62774c3371d14a14780ebe76b3cdddae61ef4d271311dd66b9024f2b0bda7c89"
        )
    ]
)
