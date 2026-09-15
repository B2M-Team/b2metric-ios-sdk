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
            url: "https://github.com/B2M-Team/b2metric-ios-sdk/releases/download/2.1.0/B2MAnalyticsSDK.xcframework.zip",
            checksum: "dfb13281dfbe711c83e1ed5c6ac1210cee43a8ad89c4b7a7617d99f2dd2e4026"
        )
    ]
)
