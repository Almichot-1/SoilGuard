# Soil Sense

Soil Sense is a Flutter app that helps smallholders and agronomists quickly evaluate fields: it connects to a BLE soil sensor, maps your walk with GPS, computes area, and recommends suitable crops with concrete planting guidance (seed rate, spacing, and plant counts).

## Overview

## HC-05 / BC417 (Bluetooth Classic) Sensor Input

This app supports receiving live soil readings over **Bluetooth Classic (SPP)** from modules like **HC-05 / HC-06 / BC417**.

### Important notes

- **HC-05/BC417 is Bluetooth Classic, not BLE.** Your existing BLE code stays, but this path uses a different plugin.
- **Pair the module first** in Android Bluetooth settings before connecting from the app.
- The app will auto-connect to a paired device whose name contains `HC-05`/`HC-06` (or auto-connect if there is exactly one paired device).

### Expected data format from Arduino

Send one line per reading, ending with `\n`.

Supported formats:

- CSV (recommended minimal): `ph,moisture,temp`
	- Example: `7.1,45,23\n`
- Key-value CSV: `ph=7.1,moisture=45,temp=23`
- JSON (compatible with existing BLE JSON parsing): `{"ph":7.1,"moisture":45,"temp":23}`

The service currently maps data into `SoilData` (pH, moisture, temperature) because the app UI and recommender use those fields.

## Requirements
- Flutter SDK `>=3.9.0`

## Windows build note (spaces in user folder)

If your Windows username contains spaces (example: `C:\Users\NOOR AL MUSABAH\...`), Android builds may fail with errors like:

- `Failed to create parent directory 'C:\Users\NOOR' ...`

Build from a space-free alias path (junction) or a `subst` drive (see Setup).
## Setup
1. Ensure the crops asset is declared in `pubspec.yaml`:
	 ```yaml
	 flutter:
		 uses-material-design: true
		 assets:
			 - assets/data/crops.json
	 ```
2. Install dependencies:
	 ```powershell
	 flutter pub get
	 ```
3. If you’re on Windows and your user path contains spaces, create an alias (recommended). Examples:
	 - Junction (persistent):
		 ```powershell
		 New-Item -ItemType Junction -Path "C:\dev\soil_sense" -Target "C:\Users\NOOR AL MUSABAH\Documents\mobile_app\soil_sense"
		 cd C:\dev\soil_sense
		 ```
	 - Subst drive (session):
		 ```powershell
		 subst S: "C:\Users\NOOR AL MUSABAH\Documents\mobile_app\soil_sense"
		 S:
		 ```

	 Tip: Always build from the same path (either the original folder or the alias) to avoid Kotlin/Gradle incremental cache issues.

## Run
Use a clean rebuild to ensure assets are bundled:
```powershell
flutter clean
flutter pub get
flutter run
```

## Walkthrough
1. Home Screen
	 - Status for BLE and GPS.
	 - Live map shows your current location and captured points.
	 - AppBar toggle to enable Simulation (no hardware needed).
2. Start Scan
	 - Begins collecting GPS points as you move and soil samples from the BLE device (or simulation).
	 - The app computes area from your path.
3. Stop Scan
	 - Averages collected soil samples and calculates area.
	 - Generates recommendations and immediately shows a SnackBar with the top crop.
	 - Navigates to the Results screen.
4. Results Screen
	 - “Top Recommendation” banner with best crop and suitability.
	 - List of three recommended crops, each showing:
		 - Suitability percent
		 - Seed rate for your area (kg)
		 - Recommended spacing
		 - Estimated plant count

## Simulation Mode
- Toggle Simulation in the AppBar of the scan screen.
- Emits realistic soil data (pH, moisture, temperature) at intervals.
- Ideal for demos and verifying the end‑to‑end pipeline without hardware.

## Data & Models
- Asset: `assets/data/crops.json` (loaded at startup).
- Key models in `lib/models/`:
	- `SoilData`: pH, moisture, temperature
	- `Crop`: agronomic ranges and planting parameters
	- `Recommendation`: crop, suitability, seed kg, plant count, area

## Architecture
- `BleService`: Connects/scans BLE, parses soil samples; supports simulation.
- `GpsService`: Tracks location stream and accumulates track points for area.
- `RecommenderService`: Loads `crops.json`, scores crops, produces top 3 recommendations.
- `DatabaseService`: Persists history locally (`sqflite`).
- `flutter_map`: Renders the field polygon and markers.
- `provider`: Wires services to UI screens and widgets.

## Key Decisions
- BLE library pinned: `flutter_blue_plus: ^1.15.4` to avoid a breaking “license” parameter change in newer versions.
- Geolocator updated to `LocationSettings` API.
- Deprecated APIs cleaned (`withOpacity` → `withValues`, map marker guards).

## Troubleshooting
- Assets not loading:
	- Ensure `assets/data/crops.json` is in `pubspec.yaml` and run a clean build.
	- Commands:
		```powershell
		flutter clean
		flutter pub get
		flutter run
		```
- Gradle/Kotlin cache errors on Windows:
	- Build from the alias path without spaces (junction or `subst`).
	- If switching paths, do a clean build.
- BLE sensor unavailable:
	- Enable Simulation mode; you can still walk and compute area.
- Range errors when few map points:
	- Fixed in `LiveMapWidget`; ensure you have at least 3 points for a polygon.

## Testing Tips
- Use Simulation mode and walk a short path to collect >= 3 GPS points.
- Stop the scan to see the SnackBar and navigate to Results.
- Verify recommendations list shows seed kg, spacing, and plant count.

## Useful Commands
```powershell
flutter analyze
flutter pub outdated
flutter build apk
```

## Offline Map (Addis Ababa)
- The app can render offline tiles from an MBTiles file.
- Place an `addis.mbtiles` file in the app's Documents directory on the device:
	- Android: `/storage/emulated/0/Android/data/<your.app.id>/files/addis.mbtiles`
	- iOS: App sandbox Documents directory (via Files app, iTunes sharing, or code).
- On launch, the app will use MBTiles for tiles when available and fall back to online OSM otherwise.
- Open the map from Home → “Offline Map (Addis Ababa)”.

Note: MBTiles cannot be loaded directly from Flutter assets. Ensure OpenStreetMap attribution remains visible.

## Contributing
- Keep changes minimal and focused.
- Follow `flutter_lints` and prefer `debugPrint` over `print`.
- Update this README when adding new features or assets.

## License
Private project.
