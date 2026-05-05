# Heatbubble

**A Real-Time Pocket Temperature Tracking Application**

Heatbubble is a production-grade Flutter application that leverages device sensors to monitor and track real-time temperature fluctuations. The app provides comprehensive temperature analytics, personalized insights, and cloud synchronization with an intuitive user interface.

## Features

- **Real-Time Temperature Tracking**: Continuously monitor temperature using device sensors
- **Analytics & Visualizations**: Interactive charts and graphs for temperature trends
- **Background Monitoring**: Persistent background tasks with scheduled notifications
- **Cloud Synchronization**: Seamless Firebase integration for data persistence and real-time updates
- **User Authentication**: Secure sign-in with Firebase Authentication
- **Subscription Management**: In-app purchases and subscription handling
- **Local Database**: Offline-first architecture using SQLite (Drift ORM)
- **Push Notifications**: Timezone-aware scheduled notifications
- **Home Widget Support**: Quick-access widget for home screen
- **In-App Updates**: Automatic update management via Google Play
- **Cross-Platform**: Native support for Android, iOS, macOS, Windows, and Web

## Tech Stack

### Frontend
- **Flutter SDK**: ^3.11.1
- **UI Framework**: Material Design 3
- **Charts**: fl_chart ^0.70.2
- **Icons**: Lucide Icons Flutter
- **Fonts**: Google Fonts

### Backend & Services
- **Firebase Suite**:
  - Authentication (Firebase Auth)
  - Real-time Database (Cloud Firestore)
  - Cloud Storage
  - Cloud Messaging
  - Analytics
  
### Data & Storage
- **Local Database**: Drift ORM with SQLite3
- **Preferences**: Shared Preferences

### Background Tasks
- **Workmanager**: ^0.9.0+3 for background polling and scheduled tasks
- **Timezone**: ^0.9.4 for timezone-aware scheduling

### Other Services
- **Notifications**: Flutter Local Notifications
- **Permissions**: Permission Handler
- **Ads**: Google Mobile Ads
- **Updates**: In-App Update (Google Play)
- **Home Widget**: Home Widget Service

## Project Structure

```
heatbubble/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # App configuration
│   ├── screens/                  # UI screens
│   ├── widgets/                  # Reusable widgets
│   ├── services/                 # Business logic & integrations
│   │   ├── firebase_*.dart      # Firebase services
│   │   ├── background_service.dart
│   │   ├── subscription_service.dart
│   │   ├── ads_service.dart
│   │   └── ...
│   ├── models/                   # Data models
│   ├── database/                 # Local database (Drift)
│   └── utils/                    # Utilities & helpers
├── android/                      # Android-specific code
├── ios/                          # iOS-specific code
├── macos/                        # macOS-specific code
├── windows/                      # Windows-specific code
├── web/                          # Web-specific code
├── functions/                    # Firebase Cloud Functions
├── pubspec.yaml                  # Flutter dependencies
└── firebase.json                 # Firebase configuration
```

## Getting Started

### Prerequisites

- Flutter SDK 3.11.1 or higher
- Dart SDK 3.11.1 or higher
- Android Studio / Xcode (for mobile development)
- Firebase project account
- Google Play Developer account (for in-app purchases and updates)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd heatbubble
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Configure FlutterFire
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

4. **Set up environment variables**
   - Create `.env` file with necessary API keys and configuration
   - Ensure `android/key.properties` is properly configured for signing

5. **Run the app**
   ```bash
   # Development
   flutter run
   
   # Release (Android)
   flutter build apk --release
   
   # Release (iOS)
   flutter build ios --release
   ```

## Building for Production

### Android
```bash
# Build AAB for Play Store
flutter build appbundle --release

# Build APK
flutter build apk --release
```

### iOS
```bash
# Build for App Store
flutter build ios --release
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -config Release -derivedDataPath build
```

### Web
```bash
flutter build web --release
```

## Deployment

### Firebase Deployment
```bash
firebase deploy
```

This deploys Cloud Functions and Firestore rules to your Firebase project.

### Google Play Deployment
1. Build release APK/AAB
2. Sign with app key (configured in `android/key.properties`)
3. Upload to Google Play Console
4. Review release notes and submit

## Configuration

### Firestore Rules
Update [firestore.rules](firestore.rules) to define access control and validation rules.

### Storage Rules
Configure [storage.rules](storage.rules) for secure file access.

### Firestore Indexes
Define custom indexes in [firestore.indexes.json](firestore.indexes.json) for optimal query performance.

## Development

### Running Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Formatting
```bash
flutter format lib/
```

### Build Runner (for Drift code generation)
```bash
dart run build_runner build
```

## Architecture

Heatbubble follows a **layered architecture**:

- **Presentation Layer**: Screens and widgets
- **Business Logic Layer**: Services (Firebase, subscription, ads, etc.)
- **Data Layer**: Local database (Drift) and remote database (Firestore)
- **Infrastructure Layer**: Firebase, notifications, permissions, background tasks

## Performance Optimizations

- **Background Tasks**: Efficient polling with Workmanager
- **Local Caching**: Drift-based SQLite for offline functionality
- **Lazy Loading**: UI elements load on-demand
- **Image Optimization**: Cached images with efficient memory management

## Security

- Firebase Security Rules for data access control
- Signed APK/AAB for app integrity
- Sensitive data stored securely using device keystore
- HTTPS for all API communications

## Monitoring & Analytics

- Firebase Analytics for user behavior tracking
- Crash reporting via Firebase Crashlytics
- Performance monitoring for stability insights

## Troubleshooting

### Build Issues
- Clear build cache: `flutter clean && flutter pub get`
- Update Flutter: `flutter upgrade`
- Check Dart version compatibility

### Firebase Connection Issues
- Verify Firebase configuration via `flutterfire configure`
- Check internet connectivity
- Validate Firebase Security Rules

### Background Task Issues
- Ensure appropriate permissions are granted
- Check Workmanager configuration in `services/background_service.dart`

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -m 'Add feature'`
3. Push to branch: `git push origin feature/your-feature`
4. Open a Pull Request

## License

This project is licensed under proprietary terms. See LICENSE file for details.

## Support

For issues, feature requests, or questions, please contact the development team or open an issue in the repository.

## Release Notes

See [PLAY_STORE_RELEASE_NOTES.txt](PLAY_STORE_RELEASE_NOTES.txt) for version history and deployment notes.
