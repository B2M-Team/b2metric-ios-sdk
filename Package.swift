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
            url: "https://github.com/B2M-Team/b2metric-ios-sdk/releases/download/2.2.0/B2MAnalyticsSDK.xcframework.zip",
            checksum: "c7fa8d0c68681ff6310cce3875e2d21ae3efbde1382325956b32b75d0fa5fb75"
        )
    ]
)
