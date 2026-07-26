# UDC Product Foundation

## Product problem

Drivers use vehicles with radically different instrumentation and connectivity. UDC aims to provide one useful, private driving companion whether a car exposes OBD-II data, only supplies location-derived motion, or needs manually configured driveline information.

## Target users

- Drivers of modern OBD-II-equipped vehicles
- Owners of classics without diagnostic electronics
- Restomod and engine-swap builders
- Drivers who want simple GPS-only trip information
- Enthusiasts who may later configure driveline data for estimated RPM

## Product principles

1. Every car is supported at a meaningful baseline.
2. OBD-II enhances the experience but never gates it.
3. Important state is understandable, accessible, and not communicated by color alone.
4. Driving data stays on device unless the user explicitly enables a future sharing or cloud feature.
5. Features should earn their complexity and keep safety central.

## Data modes

**GPS only:** the default broadly compatible path. Future location-derived speed and trip recording will not require OBD-II.

**Optional OBD-II:** a future enhanced source for live values such as engine RPM. Bluetooth and adapter support are outside this skeleton.

**Manual/classic:** a foundation for vehicles that may use tire diameter, axle ratio, and transmission ratios to estimate RPM. The skeleton stores these concepts but performs no calculation.

## Navigation

The primary iPhone tabs are Dashboard, Drives, Performance, Garage, and More. More contains Fuel and Settings, keeping the tab bar focused while preserving all six product areas.

## Monetization hypothesis

The current hypothesis is a limited free allowance based on total driven miles and completed Performance runs, followed by an optional one-time lifetime unlock. Provisional values are centralized as 25 miles and 10 Performance runs. Pricing, StoreKit, paywalls, subscriptions, and advertising are intentionally absent.

## Out of scope for this skeleton

- Location permissions, live tracking, and route storage
- Bluetooth, OBD-II discovery, transport, and PID decoding
- Fuel-economy calculations and Gas911 behavior
- Performance timing
- Purchases, advertisements, analytics, networking, and cloud sync
- Full driveline, maintenance, and adapter configuration

## Architectural decisions

- SwiftUI lifecycle with an iPhone-only target
- SwiftData for local vehicle persistence
- Feature-oriented folders with small service protocols
- Simple composition and initializer-friendly boundaries, without a DI framework
- Value types for data-source and connection domains; SwiftData only where persistence is required
- Semantic adaptive colors and Dynamic Type layouts
- Unit tests focused on stable domain behavior rather than fragile UI snapshots
