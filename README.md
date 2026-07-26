# UDC

UDC is a native iPhone driving companion designed for modern OBD-II vehicles, classics, restomods, and GPS-only driving. OBD-II is an optional enhancement; the app is intended to remain useful without an adapter.

## Status

This repository contains the initial SwiftUI and SwiftData application skeleton. It includes onboarding, a dashboard hierarchy, Garage persistence, feature placeholders, service boundaries, a small design system, and foundational domain tests.

OBD-II communication, live GPS tracking, fuel calculations, Performance timing, purchases, and Gas911 are **not implemented**.

## Development environment

- Xcode 26 or newer
- iOS 17.0 or newer (SwiftData minimum)
- iPhone simulator or device
- No third-party dependencies

## Build

Open `UDC.xcodeproj` in Xcode, select the UDC scheme and an iPhone destination, then Run. From Terminal:

```sh
xcodebuild -project UDC.xcodeproj -scheme UDC -showdestinations
xcodebuild -project UDC.xcodeproj -scheme UDC -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild -project UDC.xcodeproj -scheme UDC -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Adjust the simulator name to one installed locally.

## Architecture

The project uses a lightweight feature-oriented structure. `App` owns composition and onboarding, `Core` defines system-integration boundaries and domain policies, `Models` contains SwiftData and value models, `Features` contains screens, and `DesignSystem` contains reusable visual primitives. Dependencies use simple protocol and initializer boundaries rather than a framework.

## Current skeleton

- Dashboard, Drives, Performance, Garage, and More tabs
- Fuel and Settings within More
- SwiftData-backed basic vehicle creation and active-vehicle selection
- First-launch connection-choice flow
- Mock/no-op location, driving-session, and OBD services
- Centralized provisional free-usage policy
- Focused unit tests for foundational domain behavior

## Near-term roadmap

1. Add real, permission-aware location tracking and drive recording.
2. Define the OBD adapter and PID transport layer without coupling it to UI.
3. Expand manual driveline configuration and validate RPM estimation requirements.
4. Add drive-history detail and fuel records.
5. Prototype Performance timing with explicit safety guidance.

## Repository rules

UDC and A-Speed are separate products and separate codebases. UDC must not depend on, copy, or reference A-Speed source code, assets, packages, themes, or branding. Architectural ideas may be evaluated independently, but UDC owns its architecture, design system, model, roadmap, and release cycle.
