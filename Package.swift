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
            url: "https://github.com/B2M-Team/b2metric-ios-sdk/releases/download/1.0.0/B2MAnalyticsSDK.xcframework.zip",
            checksum: "b7ad94de6f1895c4a4a3e77fd6b0c850fbfb38a245c61326fd2ce042f889ac8c"
        )
    ]
)
