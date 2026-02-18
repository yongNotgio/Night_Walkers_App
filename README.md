# Night Walkers App

Night Walkers is a personal safety app designed for anyone walking alone at night. With a single tap, you can instantly alert your emergency contacts and share your real-time location, helping you feel safer wherever you go.

## Key Features

- **Panic Button:** Instantly send an emergency alert and your live location to trusted contacts.
- **Location Sharing:** Real-time GPS tracking so your contacts know where you are.
- **Multi-Channel Alerts:** Sends SMS, triggers a loud alarm, flashes your flashlight, and vibrates your phone for maximum visibility.
- **Emergency Contacts:** Easily add and manage the people you trust most.
- **Volume Button Trigger:** Activate the alarm discreetly by pressing your phone’s volume button multiple times.
- **Offline Support:** Core safety features work even without an internet connection.
- **Cross-Platform:** Available for Android, iOS, Web, Windows, and Linux.

## How It Works

1. **Set Up Emergency Contacts:** Add friends or family who will be notified in an emergency.
2. **Activate the Panic Button:** Tap the button or use the volume trigger to start the alarm.
3. **Automatic Alerts:** Your contacts receive your location and a custom message via SMS.
4. **Stay Visible:** The app sounds an alarm, flashes your flashlight, and vibrates to attract attention.

## Who Is It For?

- Night walkers, joggers, and commuters
- Students and campus safety
- Anyone who wants extra peace of mind when alone

## Download

- [Download the latest Android APK (v6.1.0)](releases/NightWalkers-v6.1.0-release.apk)

## Privacy & Security

Night Walkers only shares your location with your chosen emergency contacts during an active alert. Your data stays private and secure.

---

**Version:** 6.1.0  
**Last Updated:** February 2026
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

**Version**: 1.0.0  
**Last Updated**: February 2026  
**Status**: Active Development
