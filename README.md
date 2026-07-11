# B2Metric Analytics SDK for iOS

B2Metric Analytics iOS SDK — event tracking, user identification and push analytics for your iOS app.

Distributed as a precompiled binary (XCFramework) via Swift Package Manager.

## Requirements

- iOS 13.0+
- Swift 5.5+ / Xcode 13+

## Installation

### Swift Package Manager

In Xcode: **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/B2M-Team/b2metric-ios-sdk
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/B2M-Team/b2metric-ios-sdk", from: "1.0.0")
]
```

Then add `B2MAnalyticsSDK` to your target's dependencies.

## Getting Started

Start the SDK once, as early as possible (e.g. in your `App` init or `AppDelegate`):

```swift
import B2MAnalyticsSDK

B2MAnalytics.shared.start(apiKey: "YOUR_API_KEY")
```

Optional configuration:

```swift
B2MAnalytics.shared.start(
    apiKey: "YOUR_API_KEY",
    batchSize: 20,        // events per batch (default: 20)
    flushInterval: 30     // seconds between flushes (default: 30)
)
```

## Usage

### Log an event

```swift
B2MAnalytics.shared.logEvent(name: "product_viewed")

B2MAnalytics.shared.logEvent(
    name: "purchase",
    properties: [
        "product_id": AnyCodable("SKU-123"),
        "price": AnyCodable(49.90),
        "currency": AnyCodable("TRY")
    ]
)
```

### Identify a user

```swift
let user = B2MUser(
    userId: "user-123",
    name: "Ada",
    surname: "Lovelace",
    email: "ada@example.com"
)
B2MAnalytics.shared.setUser(user)
```

### Push notifications

Register the device token (from `didRegisterForRemoteNotificationsWithDeviceToken`):

```swift
B2MAnalytics.shared.registerDeviceToken(deviceToken)
```

Track a push open (when the user taps a notification):

```swift
B2MAnalytics.shared.trackPushOpened(userInfo: response.notification.request.content.userInfo)
```

### Logging

Control SDK log verbosity (default: `.off`):

```swift
B2MAnalytics.shared.logLevel = .info   // .off, .error, .warning, .info, .debug
```

## License

Copyright © B2Metric. All rights reserved.
