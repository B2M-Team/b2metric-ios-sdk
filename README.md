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
    .package(url: "https://github.com/B2M-Team/b2metric-ios-sdk", from: "2.0.0")
]
```

Then add `B2MAnalyticsSDK` to your target's dependencies.

## Upgrading from 1.x

2.0.0 aligns the iOS SDK's payload and behaviour with the other B2Metric
platform SDKs. Two changes require an edit at your call sites:

| 1.x | 2.0.0 |
|-----|-------|
| `start(apiKey:)` | `start(apiKey:appIdentifier:)` — `appIdentifier` is now required |
| `setUser` attributes were sent once | attributes now ride along on every subsequent event |

Everything else is additive. Notable behaviour fixes you get for free:

- An authentication failure no longer disables the SDK or discards queued
  events; only the rejected batch is dropped.
- The pending-event queue is bounded (`maxQueueSize`, default 1000) instead
  of growing without limit.
- The SDK no longer requests location permission or collects coordinates.
- A single non-finite number in an event's properties no longer blocks the
  queue.

## Getting Started

Start the SDK once, as early as possible (e.g. in your `App` init or `AppDelegate`):

```swift
import B2MAnalyticsSDK

B2MAnalytics.shared.start(
    apiKey: "YOUR_API_KEY",
    appIdentifier: "my_app"
)
```

`appIdentifier` must be lowercase snake_case: it starts with a letter and
contains only `a-z`, `0-9` and single `_` separators.

### Configuration

| Parameter               | Type             | Default                        | Range     | Description                                    |
|-------------------------|------------------|--------------------------------|-----------|------------------------------------------------|
| `apiKey`                | `String`         | required                       | non-empty | Your B2Metric API key                          |
| `appIdentifier`         | `String`         | required                       | snake_case| Identifies your app in B2Metric                |
| `baseUrl`               | `String`         | `https://tracker.b2metric.com` |           | Override only for a test or staging endpoint   |
| `batchSize`             | `Int`            | `20`                           | 1–100     | Events per batch and per delivery request      |
| `flushInterval`         | `TimeInterval`   | `30`                           | 1–3600    | Seconds between periodic flushes               |
| `maxRetries`            | `Int`            | `3`                            | 1–10      | Failed passes before a retry warning is logged |
| `sessionTimeoutMinutes` | `Int`            | `30`                           | 1–10080   | Inactivity window before a new session starts  |
| `maxQueueSize`          | `Int`            | `1000`                         | 100–10000 | Undelivered events kept on device              |
| `experimentIds`         | `[String]`       | `[]`                           |           | Experiments this app takes part in (see [A/B Testing](#ab-testing)) |
| `experimentsBaseUrl`    | `String`         | `https://experiments-api.b2metric.com` |   | Override only for a test or staging endpoint   |

Out-of-range numeric values are clamped to the nearest valid value rather
than throwing, so a misconfiguration degrades instead of crashing your app.

An empty `apiKey` or a malformed `appIdentifier` is different: the SDK logs
an error and stays disabled, and every later call is a silent no-op. Set
`logLevel` to at least `.error` while integrating so that failure is visible
rather than looking like an SDK that simply sends nothing.

```swift
B2MAnalytics.shared.start(
    apiKey: "YOUR_API_KEY",
    appIdentifier: "my_app",
    batchSize: 20,
    flushInterval: 30,
    sessionTimeoutMinutes: 30,
    maxQueueSize: 1000
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

Event names must be non-empty and at most 255 characters. Property values
must be JSON-compatible (`String`, finite `Number`, `Bool`, `Date`, arrays,
dictionaries); anything else is dropped with a warning rather than being
coerced to a string.

Use `itemProperties` for row-level data such as cart lines or search results:

```swift
B2MAnalytics.shared.logEvent(
    name: "add_to_cart",
    properties: ["total": AnyCodable(3000)],
    itemProperties: [
        ["id": AnyCodable("SKU-123"), "name": AnyCodable("Running Shoes")],
        ["id": AnyCodable("SKU-456"), "name": AnyCodable("Socks")]
    ]
)
```

### Identify a user

```swift
let user = B2MUser(
    userId: "user-123",
    name: "Ada",
    surname: "Lovelace",
    email: "ada@example.com",
    customAttributes: ["plan": AnyCodable("premium")]
)
B2MAnalytics.shared.setUser(user)
```

This logs a `user_identify` event and attaches the user's attributes to
every subsequent event. Each call replaces the previously set user, and the
user is not persisted across app launches — call `setUser` again on each
launch once the user is known.

Device-collected properties always win a key collision with a custom
attribute.

### Push notifications

Register the device token (from `didRegisterForRemoteNotificationsWithDeviceToken`):

```swift
B2MAnalytics.shared.registerDeviceToken(deviceToken)
```

Safe to call on every launch: an unchanged token is a no-op.

Track a push open (when the user taps a notification):

```swift
B2MAnalytics.shared.trackPushOpened(userInfo: response.notification.request.content.userInfo)
```

The notification payload's fields become the event's properties directly.

### Silent control messages

B2Metric sends silent background pushes (for example an uninstall-detection
`registration_probe`, marked by a top-level `b2m_control` key) that are never
meant for the user. iOS does not display them, and `trackPushOpened` ignores
them, so they never become a `push_opened` event even if your app calls it for
every incoming push.

If your app handles background pushes itself in
`application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`, return
early for control messages:

```swift
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if B2MAnalytics.isControlMessage(userInfo) {
        completionHandler(.noData)
        return
    }
    // ... your own handling of real pushes
}
```

### A/B testing

Show different variants to different devices and let B2Metric decide who sees
what. Experiments are created in your B2Metric panel; your app reads the
assignment and renders accordingly.

Assignments are fetched when the SDK starts, stored on the device, and read
synchronously — there is no loading state to thread through your UI.

List the experiments your app takes part in:

```swift
B2MAnalytics.shared.start(
    apiKey: "YOUR_API_KEY",
    appIdentifier: "my_app",
    experimentIds: ["YOUR_EXPERIMENT_ID"]
)
```

In SwiftUI, hold a `B2MExperiments` near the root and read a group from it.
Views re-render on their own when assignments change:

```swift
@main
struct MyApp: App {
    @StateObject private var experiments = B2MExperiments()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(experiments)
        }
    }
}

struct CheckoutButton: View {
    @EnvironmentObject private var experiments: B2MExperiments

    var body: some View {
        if experiments.group(for: "YOUR_EXPERIMENT_ID") == "YOUR_GROUP_ID" {
            BuyNowButton()
        } else {
            ContinueToCheckoutButton()
        }
    }
}
```

In UIKit, read it directly — it returns immediately:

```swift
let groupId = B2MAnalytics.shared.experimentGroupId(for: "YOUR_EXPERIMENT_ID")
```

**Every experiment needs a default.** The SDK never blocks rendering — when it
has no answer it returns `nil`, whether the device is outside the experiment's
audience, the experiment has ended, or the first answer has not arrived yet.
Keep every identifier in one file that resolves `nil` to a default, so no call
site can forget it.

> 📖 **[Full A/B testing guide →](docs/experiments.md)** — finding your group
> identifiers, verifying the integration, offline and first-launch behaviour,
> identified users, cleaning up a finished experiment, and troubleshooting.

### Screen tracking

`UIViewController` appearances are tracked automatically as `screen_view`
events. For SwiftUI, mark the views you want tracked:

```swift
ContentView()
    .trackScreen()          // uses the view's type name
    .trackScreen("checkout") // or an explicit name
```

### Flush on demand

Events are delivered automatically (batch size, periodic interval, app
foreground/background, network reconnect). Call `flush()` only when delivery
must not wait for the next trigger:

```swift
B2MAnalytics.shared.flush()
```

### Shutdown

Stops timers and observers after one final delivery attempt. Undelivered
events stay on disk and are sent after the next `start`:

```swift
B2MAnalytics.shared.shutdown()
```

### Logging

Control SDK log verbosity (default: `.off`):

```swift
B2MAnalytics.shared.logLevel = .info   // .off, .error, .warning, .info, .debug
```

## Sessions

A session starts on first launch and ends after `sessionTimeoutMinutes` of
inactivity. The SDK emits `session_start` when a session begins and
`session_end` (carrying `duration_seconds`) once the previous session is
found to have expired. Sessions survive app restarts within the timeout
window.

## Offline behaviour

Events are persisted on device and delivered in batches. While offline the
SDK skips delivery and keeps events queued, then flushes automatically when
connectivity returns. If the queue reaches `maxQueueSize`, the oldest events
are dropped first.

## License

Copyright © B2Metric. All rights reserved.
