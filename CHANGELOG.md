# Changelog

All notable changes to Spinline. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-24

First release.

### Added

- TrainerKit: byte-level codecs for the Fitness Machine Service (Indoor Bike Data, Control Point, Feature, Status, Supported Power Range) and Heart Rate Measurement, checked against FTMS v1.0 and the GATT Specification Supplement.
- TrainerKit: `GATTTransport`, the FTMS client `FTMSTrainer` (one procedure at a time, answers matched to requests, control requested again after it is lost), and a CoreBluetooth transport and trainer discovery.
- RideEngine: cycling physics, an energy-based ride simulator, workout plans and controller, ERG target pacing, route indexes from GPS tracks, and video sync.
- VirtualTrainer: an FTMS trainer in software with a virtual rider.
- iOS app: Devices, Ride, Workouts, Session and Routes screens; feature modules with `@Observable` view models; Mac Catalyst build.
- Tools: `spinline-sim`, `route-index`, route video scripts, `tools/dev.sh`.
- CI: Linux, macOS, iOS simulator UI tests with screenshots and a recording, Mac Catalyst build; a Jenkinsfile with the Linux stages.

### Not yet

- Tested against a physical trainer or on a physical iPhone.
- Backend from an OpenAPI specification and group rides.
- Ride export, voice cues.
