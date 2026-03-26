# Firebase Setup Guide for HeatBubble

This guide will help you configure Firebase for your HeatBubble app with Authentication, Firestore, Storage, and Cloud Messaging.

## Prerequisites

- Flutter SDK installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Google account for Firebase Console

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `heatbubble` (or your preferred name)
4. Enable Google Analytics (optional but recommended)
5. Click "Create project"

## Step 2: Add Android App to Firebase

1. In Firebase Console, click the Android icon
2. Enter Android package name: `com.example.heatbubble` (match your `android/app/build.gradle.kts`)
3. Enter app nickname: `HeatBubble Android`
4. Download `google-services.json`
5. Place it in `android/app/` directory

## Step 3: Configure Android

### Update `android/build.gradle.kts`:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

### Update `android/app/build.gradle.kts`:

Add at the bottom of the file:

```kotlin
apply(plugin = "com.google.gms.google-services")
```

## Step 4: Generate Firebase Options for Flutter

Run this command in your project root:

```bash
flutterfire configure
```

This will:
- Create `lib/firebase_options.dart` with your Firebase configuration
- Configure Firebase for Android (and iOS if you add it later)

## Step 5: Enable Firebase Services

### 5.1 Authentication

1. In Firebase Console, go to **Authentication**
2. Click "Get started"
3. Enable sign-in methods:
   - **Email/Password** (for user accounts)
   - **Anonymous** (for guest users)
4. Click "Save"

### 5.2 Cloud Firestore

1. Go to **Firestore Database**
2. Click "Create database"
3. Choose **Start in test mode** (for development)
4. Select a location (choose closest to your users)
5. Click "Enable"

**Security Rules (for production):**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Readings - users can only access their own
    match /readings/{readingId} {
      allow read, write: if request.auth != null && 
                           resource.data.userId == request.auth.uid;
    }
    
    // Subscriptions - users can only read their own
    match /subscriptions/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false; // Only backend can write
    }
  }
}
```

### 5.3 Firebase Storage

1. Go to **Storage**
2. Click "Get started"
3. Choose **Start in test mode** (for development)
4. Click "Done"

**Security Rules (for production):**

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only access their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5.4 Cloud Messaging (Push Notifications)

1. Go to **Cloud Messaging**
2. Click "Get started"
3. No additional configuration needed - it's automatically enabled

## Step 6: Create Firestore Indexes

For better query performance, create these indexes:

1. Go to **Firestore Database** → **Indexes**
2. Click "Create index"

**Index 1: User Readings by Timestamp**
- Collection ID: `readings`
- Fields:
  - `userId` (Ascending)
  - `timestamp` (Descending)
- Query scope: Collection

## Step 7: Install Dependencies

Run in your project root:

```bash
flutter pub get
```

## Step 8: Test Firebase Connection

Run your app:

```bash
flutter run
```

Check the console logs for:
- `✅ [Firebase] Core initialized`
- `✅ [Firebase] All services initialized`

## Firebase Services Overview

### Authentication (`firebase_auth_service.dart`)

```dart
final auth = FirebaseAuthService();

// Sign up
await auth.signUpWithEmail(
  email: 'user@example.com',
  password: 'password123',
  displayName: 'John Doe',
);

// Sign in
await auth.signInWithEmail(
  email: 'user@example.com',
  password: 'password123',
);

// Anonymous sign in
await auth.signInAnonymously();

// Sign out
await auth.signOut();
```

### Firestore (`firebase_firestore_service.dart`)

```dart
final firestore = FirebaseFirestoreService();

// Save user profile
await firestore.saveUserProfile(
  userId: 'user123',
  data: {
    'name': 'John Doe',
    'email': 'john@example.com',
  },
);

// Save temperature reading
await firestore.saveReading(
  userId: 'user123',
  reading: TempReading(...),
);

// Stream user readings
firestore.getUserReadings(userId: 'user123').listen((readings) {
  print('Got ${readings.length} readings');
});

// Save subscription
await firestore.saveSubscription(
  userId: 'user123',
  isPremium: true,
  purchaseId: 'purchase_123',
  productId: 'premium_onetime',
);
```

### Storage (`firebase_storage_service.dart`)

```dart
final storage = FirebaseStorageService();

// Upload profile picture
final url = await storage.uploadProfilePicture(
  userId: 'user123',
  imageFile: File('/path/to/image.jpg'),
);

// Upload chart image
final chartUrl = await storage.uploadChartImage(
  userId: 'user123',
  imageFile: File('/path/to/chart.png'),
  chartId: 'chart_123',
);

// Delete user files
await storage.deleteUserFiles('user123');
```

### Cloud Messaging

```dart
final firebase = FirebaseInitService();

// Get FCM token
final token = firebase.fcmToken;

// Subscribe to topic
await firebase.subscribeToTopic('temperature_alerts');

// Unsubscribe from topic
await firebase.unsubscribeFromTopic('temperature_alerts');
```

## Data Structure

### Firestore Collections

**users/{userId}**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

**readings/{readingId}**
```json
{
  "userId": "user123",
  "temperature": 36.5,
  "rawTemp": 36.2,
  "timestamp": "2024-01-01T12:00:00Z",
  "createdAt": "2024-01-01T12:00:00Z"
}
```

**subscriptions/{userId}**
```json
{
  "userId": "user123",
  "isPremium": true,
  "purchaseId": "purchase_123",
  "productId": "premium_onetime",
  "expiryDate": null,
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## Security Best Practices

1. **Never commit `google-services.json` to public repos**
   - Add to `.gitignore` if needed

2. **Use Security Rules in production**
   - Switch from test mode to production rules
   - Validate user authentication
   - Restrict write access

3. **Enable App Check** (optional but recommended)
   - Protects your backend from abuse
   - Go to Firebase Console → App Check

4. **Monitor Usage**
   - Check Firebase Console → Usage and billing
   - Set up budget alerts

## Troubleshooting

### Issue: "Firebase not initialized"
**Solution:** Make sure `flutterfire configure` was run and `firebase_options.dart` exists

### Issue: "Permission denied" in Firestore
**Solution:** Check your security rules and ensure user is authenticated

### Issue: "Storage upload fails"
**Solution:** Verify storage rules allow the user to write to their directory

### Issue: "FCM token is null"
**Solution:** Check notification permissions are granted

## Next Steps

1. Implement user authentication UI
2. Sync local data to Firestore
3. Set up cloud backup/restore
4. Implement push notifications for temperature alerts
5. Add analytics tracking

## Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
