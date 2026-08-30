# A/B Testing

Run experiments in your app and let B2Metric decide which variant each device
sees. The SDK fetches the current assignments, stores them on the device, and
returns them synchronously — so a variant is available while a view renders,
with no loading state to thread through your UI.

**Contents**

- [Before you start](#before-you-start)
- [Step 1 — Configure the SDK](#step-1--configure-the-sdk)
- [Step 2 — Map identifiers to names](#step-2--map-identifiers-to-names)
- [Step 3 — Read the variant](#step-3--read-the-variant)
- [SwiftUI](#swiftui)
- [UIKit](#uikit)
- [Finding your group identifiers](#finding-your-group-identifiers)
- [Verifying the integration](#verifying-the-integration)
- [Handling the first launch](#handling-the-first-launch)
- [Identified users](#identified-users)
- [When an experiment ends](#when-an-experiment-ends)
- [Behaviour reference](#behaviour-reference)
- [Troubleshooting](#troubleshooting)
- [API reference](#api-reference)

## Before you start

Experiments are created and managed in your B2Metric panel, not in your app.
Your app's job is to read the assignment and render accordingly.

You will need:

| What | Where it comes from | Used for |
|------|--------------------|----------|
| Experiment id | Created in the B2Metric panel | Telling the SDK which experiments to fetch |
| Group ids | Created with the experiment | Deciding which variant to render |

Both are opaque identifiers. Your app compares them but never interprets them —
see [Step 2](#step-2--map-identifiers-to-names) for how to keep them contained,
and [Finding your group identifiers](#finding-your-group-identifiers) if you do
not have the group ids yet.

**Plan the default first.** The SDK never blocks rendering: when it has no
answer it returns `nil`, and your app must still show something. Decide what
that is before you write the variant.

## Step 1 — Configure the SDK

Pass the experiments your app takes part in to `start()`. Experiments not listed
here are never fetched.

```swift
B2MAnalytics.shared.start(
    apiKey: "YOUR_API_KEY",
    appIdentifier: "my_app",
    experimentIds: [
        "4f9a1c30-8b52-4e77-9d10-6a3e2f45c8b1",
        "b71d0e94-3c18-42a6-8f55-19e7d4a20c63",
    ]
)
```

Omit `experimentIds` and the experiments module stays off entirely — no requests
are made and every read returns `nil`. Existing integrations are unaffected by
upgrading.

## Step 2 — Map identifiers to names

B2Metric identifies groups by opaque id, not by name. Comparing those ids
throughout your codebase is difficult to review and easy to get wrong.

The recommended approach is a single file that owns every identifier and exposes
meaningful names to the rest of the app. **No other file should contain a
B2Metric identifier.**

```swift
// Experiments.swift
import B2MAnalyticsSDK

enum Experiments {
    static let all = [checkoutButton.id]

    enum checkoutButton {
        static let id = "4f9a1c30-8b52-4e77-9d10-6a3e2f45c8b1"
        static let singleTap = "e58d3a17-6b40-49c5-92f1-7d0e6b28a5f3"
    }
}

enum CheckoutButtonVariant {
    case control
    case singleTap

    /// Control, not enrolled, experiment ended, or no answer yet.
    static func resolve(_ groupId: String?) -> CheckoutButtonVariant {
        groupId == Experiments.checkoutButton.singleTap ? .singleTap : .control
    }
}
```

This gives you three things worth having:

- **One place to change.** When an experiment is replaced, one file is edited.
- **A default that cannot be forgotten.** Every path that is not an explicit
  variant falls through to `.control`.
- **Type safety.** Views switch on a `CheckoutButtonVariant`, so a typo is a
  compile error rather than a silently unrendered variant.

Wire the ids into `start()` from the same file:

```swift
B2MAnalytics.shared.start(
    apiKey: "YOUR_API_KEY",
    appIdentifier: "my_app",
    experimentIds: Experiments.all
)
```

## Step 3 — Read the variant

Use ``B2MExperiments`` in SwiftUI, or the SDK directly in UIKit. Both read the
same stored assignments.

## SwiftUI

Hold a `B2MExperiments` with `@StateObject` near the root and pass it down.
Views re-render on their own when assignments change.

```swift
import SwiftUI
import B2MAnalyticsSDK

@main
struct MyApp: App {
    @StateObject private var experiments = B2MExperiments()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(experiments)
        }
    }
}
```

```swift
struct CheckoutButton: View {
    @EnvironmentObject private var experiments: B2MExperiments

    var body: some View {
        let variant = CheckoutButtonVariant.resolve(
            experiments.group(for: Experiments.checkoutButton.id)
        )

        switch variant {
        case .singleTap: BuyNowButton()
        case .control:   ContinueToCheckoutButton()
        }
    }
}
```

`B2MExperiments` may be created before `start()` — it publishes an empty,
not-ready state until the SDK is running.

## UIKit

Read the assignment directly. It returns immediately, so it is safe to call in
`viewDidLoad` or while configuring a cell.

```swift
let groupId = B2MAnalytics.shared.experimentGroupId(
    for: Experiments.checkoutButton.id
)

switch CheckoutButtonVariant.resolve(groupId) {
case .singleTap: showBuyNowButton()
case .control:   showContinueButton()
}
```

To react to changes, subscribe. The listener is called immediately with the
current state and again whenever assignments change:

```swift
let unsubscribe = B2MAnalytics.shared.addExperimentsListener { snapshot in
    guard snapshot.isReady else { return }
    self.applyVariants(snapshot.assignments)
}

// Later, when the observer is no longer needed:
unsubscribe()
```

The same call works in a service layer, a coordinator, or a request builder that
needs to send the variant to your own backend.

## Finding your group identifiers

If your panel does not show the group ids, or you want to confirm which one the
running device received, ask the SDK. Turn on debug logging and print the
assignments during development:

```swift
B2MAnalytics.shared.logLevel = .debug

B2MAnalytics.shared.addExperimentsListener { snapshot in
    guard snapshot.isReady else { return }
    print("B2Metric assignments:", snapshot.assignments)
}
```

Each entry is an `ExperimentAssignment` with `experimentId` and `groupId`. One
device only ever reveals the group it was assigned to, so to collect every group
id either check the panel or run the app on several devices.

Remove the listener and lower `logLevel` before shipping.

## Verifying the integration

Before releasing an experiment, confirm the wiring end to end:

1. **Assignments arrive.** With `logLevel = .debug`, a successful refresh logs
   how many assignments were received. Zero assignments with a live experiment
   usually means the experiment id is wrong or the device does not match the
   experiment's audience.
2. **The variant renders.** Compare the logged `groupId` against your mapping
   file and check that the matching branch is on screen.
3. **The default renders too.** Force the fallback path — airplane mode on a
   fresh install is the simplest way — and confirm the screen still works.
4. **It survives a relaunch.** Kill and reopen the app. The same variant should
   appear immediately, from the stored assignments, with no visible change.

To exercise a specific variant during development, override the resolver in your
mapping file rather than changing SDK code:

```swift
static func resolve(_ groupId: String?) -> CheckoutButtonVariant {
    #if DEBUG
    if let forced = forcedVariant { return forced }
    #endif
    return groupId == Experiments.checkoutButton.singleTap ? .singleTap : .control
}
```

## Handling the first launch

On a fresh install there is nothing stored yet. The first render shows your
default, and the variant appears once the answer arrives. From the second launch
onwards this does not happen — the stored assignments are available immediately.

For most experiments this is fine and is the recommended behaviour: the screen
is interactive straight away. If a particular screen must not change under the
user, hold it with `isReady`:

```swift
struct RootView: View {
    @EnvironmentObject private var experiments: B2MExperiments

    var body: some View {
        if experiments.isReady {
            HomeView()
        } else {
            SplashView()
        }
    }
}
```

`isReady` becomes `true` once the first refresh has **settled** — whether it
succeeded, failed, or was skipped because the device is offline. It will not
leave a user on a splash screen waiting for a network that is not there.

Use it at the narrowest scope that solves the problem. Gating your entire app
delays startup for every user to smooth over one screen.

## Identified users

Assignment always follows the **device**, not the signed-in user. A device keeps
the same variant whether or not `setUser` has been called, and calling `setUser`
never moves anyone between groups.

This is deliberate. It means a variant can never change underneath someone at
login, and a user who signs out does not become a different participant.

```swift
B2MAnalytics.shared.setUser(B2MUser(userId: "user_123"))
// Assignments are unaffected — the variant on screen stays as it is.
```

The attributes you pass to `setUser` are still sent with each assignment
request, so an experiment's audience can be defined in terms of them. Only the
identity that decides *which group* a device lands in is fixed to the device.

Two consequences worth designing around:

- **The same person on two devices may see different variants.** Each device is
  assigned independently. If an experiment must be consistent for a person
  across their devices, this module is not the right fit for it.
- **Reinstalling the app may be a new device.** iOS reissues the vendor
  identifier once all of a vendor's apps are removed, so a fresh install can
  land in a different group.

If you change user attributes that an experiment's audience depends on and want
that reflected before the next session, refresh explicitly:

```swift
B2MAnalytics.shared.setUser(user)
B2MAnalytics.shared.refreshExperiments()
```

The device stays in the group it was already assigned to; only audience matching
is re-evaluated.

## When an experiment ends

When an experiment finishes in the panel, the SDK stops returning an assignment
for it and reads fall back to `nil` — which your mapping file already turns into
the default. Nothing breaks and no release is required.

Once the winning variant is rolled out, clean up:

1. Promote the winning branch to be the only branch.
2. Delete the entry from your mapping file and its variant enum.
3. Remove the experiment id from `experimentIds`.

Leaving finished experiments configured costs a small amount of startup work and
leaves dead branches in your codebase.

## Behaviour reference

How assignments are kept up to date:

| | |
|---|---|
| **Fetched** | When the SDK starts, and at the beginning of each new session |
| **Stored** | On the device, so they survive app relaunches |
| **Replaced** | A successful refresh replaces the stored set completely, so ended experiments stop being returned |
| **On failure** | The stored assignments are kept and continue to be served |
| **Offline** | No request is attempted; stored assignments are served |

What a read returns in each state:

| Situation | `experimentGroupId(for:)` | `isReady` |
|-----------|---------------------------|-----------|
| The device is assigned to a group | the group id | `true` |
| The device does not match the experiment's audience | `nil` | `true` |
| First launch, answer not back yet | `nil` | `false` |
| Offline, assignments stored earlier | the stored group id | `true` |
| Offline, nothing stored | `nil` | `true` |
| The experiment has ended | `nil` | `true` |
| No `experimentIds` configured | `nil` | `true` |

## Troubleshooting

**Every read returns `nil`.** Work through these in order:

- Is `experimentIds` passed to `start()`, and does it contain this experiment's
  id?
- Is the experiment live in the panel?
- Does the device match the experiment's audience? Devices outside it are never
  assigned, which is correct behaviour rather than a fault.
- With `logLevel = .debug`, does a refresh log any assignments at all? None at
  all points at configuration; some but not this one points at the audience.

**The variant flips shortly after the screen appears.** Expected on a fresh
install — see [Handling the first launch](#handling-the-first-launch).

**The variant changed mid-session.** A new session started while the app was
open after a long period in the background, or the experiment was changed in the
panel and a refresh picked it up. Calling `setUser` does not cause this.

**Different devices, same user, different variants.** Expected. Assignment
follows the device, not the signed-in user, so each device is assigned
independently — see [Identified users](#identified-users).

**The variant is right in the app but wrong on the server.** The SDK does not
communicate assignments to your backend. If your API must know the variant, send
it yourself — read it with `experimentGroupId(for:)` and add it to your request.

## API reference

### `B2MAnalytics.shared.experimentGroupId(for:) -> String?`

Returns the group this device is assigned to, or `nil` when there is no
assignment. Reads from the stored assignments and returns immediately.

### `B2MAnalytics.shared.experimentAssignments() -> [ExperimentAssignment]`

Returns every known assignment. Empty when none are stored yet.

### `B2MAnalytics.shared.experimentsAreReady -> Bool`

Whether the first refresh has settled.

### `B2MAnalytics.shared.refreshExperiments(completion:)`

Fetches the latest assignments instead of waiting for the next automatic
refresh. Stored assignments are kept if the request fails. Concurrent calls
share a single request. The optional completion runs once the attempt finishes.

### `B2MAnalytics.shared.addExperimentsListener(_:) -> () -> Void`

Subscribes to assignment changes and returns a closure that removes the
listener. The listener is called immediately with the current state. Safe to
call before `start()`.

### `B2MExperiments`

`ObservableObject` for SwiftUI. Publishes `assignments` and `isReady`, and
exposes `group(for:)` and `refresh()`.

### `ExperimentAssignment`

`experimentId: String`, `groupId: String`.

### `ExperimentsSnapshot`

`assignments: [ExperimentAssignment]`, `isReady: Bool`.

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `experimentIds` | `[String]` | `[]` | Experiments this app takes part in. Empty disables the module. |
| `experimentsBaseUrl` | `String` | `https://experiments-api.b2metric.com` | Override only for a test or staging endpoint |
