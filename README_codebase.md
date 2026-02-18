# Night Walkers App – Codebase Documentation

This document provides a technical overview of the Night Walkers App codebase for developers and contributors.

## Project Structure

```
lib/
├── main.dart                 # Application entry point & initialization
├── screens/
│   ├── homescreen.dart       # Main home screen with panic button
│   ├── onboarding_screen.dart # First-time user setup
│   ├── map_screen.dart       # Live map display of location
│   ├── contacts_screen.dart  # Emergency contacts management
│   └── settings_screen.dart  # App preferences & configuration
├── services/
│   ├── direct_sms_service.dart      # SMS sending with volume trigger support
│   ├── sms_service.dart             # Alternative SMS implementation
│   ├── location_service.dart        # GPS location fetching & tracking
│   ├── flashlight_service.dart      # Torch/LED control
│   └── sound_service.dart           # Audio alarm & sound effects
└── widgets/
    ├── panic_button.dart             # Main panic button component
    ├── panic_countdown_overlay.dart  # Countdown animation overlay
    ├── status_dashboard.dart         # Status display widget
    ├── user_location_marker.dart     # Map location marker
    └── fixed_compass.dart            # Compass widget

assets/
├── animations/          # Lottie animation files (welcome, features)
├── images/              # App icons and UI images
└── sounds/              # Audio files for alerts
```

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `geolocator` | ^10.1.1 | GPS location services |
| `flutter_map` | ^6.2.1 | Interactive map display |
| `permission_handler` | ^11.4.0 | Runtime permission management |
| `torch_light` | ^1.1.0 | Flashlight/LED control |
| `audioplayers` | ^5.2.1 | Audio alarm playback |
| `vibration` | ^3.1.3 | Haptic feedback |
| `another_telephony` | ^0.4.1 | Telephony & SMS access |
| `flutter_contacts` | ^1.1.9+2 | Contact management |
| `shared_preferences` | ^2.5.3 | Local data persistence |
| `volume_controller` | ^3.4.0 | Volume button event handling |
| `flutter_compass` | ^0.8.1 | Device compass data |
| `connectivity_plus` | ^6.1.4 | Network status detection |
| `latlong2` | ^0.9.1 | Geographic coordinate handling |

## Core Services

### DirectSmsService
Handles SMS transmission with volume button trigger capability. Supports background mode activation via physical volume buttons and manages telephony permissions.

### LocationService
Manages GPS location acquisition with configurable accuracy. Provides real-time location tracking for emergency alerts.

### SoundService
Handles audio alert playback, including customizable alarm sounds and notification tones.

### FlashlightService
Controls device flashlight/torch for visual emergency signaling.

## Installation & Setup

### Prerequisites
- Flutter SDK ^3.7.2
- Dart SDK (included with Flutter)
- Android SDK 21+ or iOS 11+

### Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Night_Walkers_App
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure platform-specific settings**
   
   **Android** (`android/app/build.gradle.kts`):
   - Ensure `compileSdk` >= 34
   - Set target SDK to latest stable version

   **iOS** (`ios/Podfile`):
   - Minimum deployment target: iOS 11.0+
   - Ensure CocoaPods dependencies are resolved

4. **Run the app**
   ```bash
   flutter run
   ```

   Or for specific device:
   ```bash
   flutter run -d <device-id>
   ```

## Permissions Required

The app requests the following permissions:

- **Location**: GPS access for emergency location sharing
- **Contacts**: Reading emergency contact information
- **SMS**: Sending SMS alerts
- **Call Phone**: Initiating emergency calls
- **Vibration**: Haptic feedback
- **Camera**: Flashlight control

All permissions are requested at runtime with user explanations.

## Architecture Overview

**State Management**: Uses Dart's native state management with `StatefulWidget`

**Data Persistence**: `SharedPreferences` for user settings and onboarding status

**Asynchronous Operations**: Dart's `async`/`await` for service layer operations

**Error Handling**: Global error widget catch-all with user-friendly error screens

## Building & Deployment

### Build Android APK
```bash
flutter build apk --release
```

### Build iOS App
```bash
flutter build ios --release
```

### Build Web
```bash
flutter build web --release
```

## Development Workflow

1. **Code Organization**: Follow the existing structure (screens, services, widgets)
2. **Permissions**: Always request permissions through `permission_handler`
3. **Location**: Use `LocationService` for all GPS operations
4. **Alerts**: Use `DirectSmsService` for emergency notifications
5. **Error Handling**: Catch platform exceptions in service layer

## Testing

Run widget tests:
```bash
flutter test
```

Current test file: `test/widget_test.dart`

## Troubleshooting

**Issue**: App crashes on startup
- Solution: Ensure Flutter is up to date (`flutter upgrade`)
- Check Android SDK versions in `android/app/build.gradle.kts`

**Issue**: GPS not working
- Solution: Grant location permissions in app settings
- Verify device has GPS enabled and clear sky view

**Issue**: SMS not sending
- Solution: Grant SMS permission in app settings
- Check device has SMS capability

## Performance Considerations

- **Location Updates**: Keep refresh rate reasonable to conserve battery
- **Audio**: Pre-load sound files during initialization
- **Maps**: Use map clustering for performance with multiple markers
- **Permissions**: Cache permission status to reduce OS calls

## Platform-Specific Notes

- **Android**: Uses Material Design 3, supports dark/light themes
- **iOS**: Follows Apple's design guidelines
- **Web**: Limited GPS and SMS functionality
- **Desktop (Windows/Linux)**: Primarily for testing; limited sensor access

## Contributing

1. Create feature branches for new functionality
2. Test across multiple platforms before merging
3. Update documentation for new features
4. Follow Dart style guidelines from `analysis_options.yaml`

## License

[Add license information here]

## Support & Contact

For issues, feature requests, or questions:
- Open an issue on the repository
- Contact the development team

---

**Version**: 6.1.0  
**Last Updated**: February 2026  
**Status**: Active Development
