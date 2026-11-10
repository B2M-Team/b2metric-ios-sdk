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
            url: "https://github.com/B2M-Team/b2metric-ios-sdk/releases/download/2.2.1/B2MAnalyticsSDK.xcframework.zip",
            checksum: "e48573caa3ba227fde5449b326b4adcdd67a8daccd48bc205d46d6355d155436"
        )
    ]
)
