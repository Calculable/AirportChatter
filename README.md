# AirportChatter

A personal prototype combining airport radio with ambient music. Open `AirportChatter.xcodeproj` in Xcode to build for iOS or macOS.

## Local station catalog

The station catalog is intentionally **not committed**. Supply a catalog you are authorized to use at `AirportChatter/Data/default_stations.json`. Its format is an array of `Station` objects; see `examples/default_stations.example.json` for a fictional, non-playable example. Without a local catalog, the app builds with an empty station list. Xcode includes the local JSON in app builds, so excluding it from Git does not exclude it from distributed binaries.

The existing local catalog is preserved on this development machine. Back it up separately before using commands that delete ignored files. A Git checkout alone cannot restore it.

LiveATC's terms restrict dedicated applications, redistribution, and direct stream linking. No permission to redistribute its directory has been established here; `.gitignore` is a repository precaution, not a license. See [LiveATC's terms](https://www.liveatc.net/legal/) and [catalog notes](docs/station-catalog.md). Obtain the appropriate permissions before sharing a catalog or distributing an app that uses the service.

## Checks

The standalone checks in `tests/` include run instructions. Catalog-specific checks run only when the local catalog is present. The other checks use synthetic fixtures and do not require live services.
