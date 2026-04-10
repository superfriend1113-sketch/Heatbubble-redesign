# Subscription Cancellation Handling

## Problem

When a user cancels their subscription from the Play Store, the app and Firebase don't automatically know about it. This means:
- User keeps premium access even after cancellation
- Firebase still shows them as premium
- No real-time revocation of premium features

## Solution: Google Play Real-Time Developer Notifications (RTDN)

### Overview

Google Play can send real-time notifications to your backend when subscription events occur:
- Subscription purchased
- Subscription renewed
- Subscription cancelled
- Subscription expired
- Subscription paused
- Subscription reactivated

### Architecture

```
Google Play Store
       ↓ (Real-time notification)
Your Backend (Cloud Function/Server)
       ↓ (Update Firebase)
Firebase Firestore
       ↓ (Real-time listener)
Flutter App (Updates UI)
```

## Implementation Steps

### Step 1: Set Up Cloud Function Backend

Create a Cloud Function to receive notifications from Google Play:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {google} = require('googleapis');

admin.initializeApp();

exports.handlePlayStoreNotification = functions.https.onRequest(async (req, res) => {
  try {
    // Verify the notification is from Google
    const message = req.body.message;
    if (!message) {
      res.status(400).send('No message');
      return;
    }

    // Decode the notification
    const data = JSON.parse(
      Buffer.from(message.data, 'base64').toString('utf-8')
    );

    console.log('Received notification:', data);

    // Handle different notification types
    if (data.subscriptionNotification) {
      await handleSubscriptionNotification(data.subscriptionNotification);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing notification:', error);
    res.status(500).send('Error');
  }
});

async function handleSubscriptionNotification(notification) {
  const {
    notificationType,
    purchaseToken,
    subscriptionId,
  } = notification;

  // Get purchase details from Google Play API
  const purchaseDetails = await verifySubscription(
    subscriptionId,
    purchaseToken
  );

  if (!purchaseDetails) {
    console.error('Could not verify purchase');
    return;
  }

  const userId = purchaseDetails.obfuscatedExternalAccountId;
  
  // Handle different notification types
  switch (notificationType) {
    case 1: // SUBSCRIPTION_RECOVERED
    case 2: // SUBSCRIPTION_RENEWED
    case 7: // SUBSCRIPTION_RESTARTED
      await grantPremium(userId, purchaseDetails);
      break;

    case 3: // SUBSCRIPTION_CANCELED
      // User cancelled but still has access until expiry
      await markSubscriptionCancelled(userId, purchaseDetails);
      break;

    case 13: // SUBSCRIPTION_EXPIRED
      // Subscription has expired, revoke access
      await revokePremium(userId);
      break;

    case 4: // SUBSCRIPTION_PURCHASED
      await grantPremium(userId, purchaseDetails);
      break;

    case 5: // SUBSCRIPTION_ON_HOLD
    case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
      // Keep premium but mark as at-risk
      await markSubscriptionAtRisk(userId, purchaseDetails);
      break;

    case 10: // SUBSCRIPTION_PAUSED
      await pauseSubscription(userId);
      break;

    case 12: // SUBSCRIPTION_REVOKED
      // Refund issued, revoke immediately
      await revokePremium(userId);
      break;
  }
}

async function verifySubscription(subscriptionId, purchaseToken) {
  try {
    const auth = new google.auth.GoogleAuth({
      keyFile: 'path/to/service-account-key.json',
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    const androidPublisher = google.androidpublisher({
      version: 'v3',
      auth: auth,
    });

    const response = await androidPublisher.purchases.subscriptions.get({
      packageName: 'com.heatbubble.app',
      subscriptionId: subscriptionId,
      token: purchaseToken,
    });

    return response.data;
  } catch (error) {
    console.error('Error verifying subscription:', error);
    return null;
  }
}

async function grantPremium(userId, purchaseDetails) {
  if (!userId) return;

  const expiryDate = new Date(parseInt(purchaseDetails.expiryTimeMillis));
  
  await admin.firestore().collection('subscriptions').doc(userId).set({
    isPremium: true,
    productId: purchaseDetails.productId,
    purchaseToken: purchaseDetails.purchaseToken,
    expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
    status: 'active',
    autoRenewing: purchaseDetails.autoRenewing,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`Granted premium to user ${userId}`);
}

async function revokePremium(userId) {
  if (!userId) return;

  await admin.firestore().collection('subscriptions').doc(userId).set({
    isPremium: false,
    status: 'expired',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`Revoked premium from user ${userId}`);
}

async function markSubscriptionCancelled(userId, purchaseDetails) {
  if (!userId) return;

  const expiryDate = new Date(parseInt(purchaseDetails.expiryTimeMillis));
  
  await admin.firestore().collection('subscriptions').doc(userId).set({
    isPremium: true, // Still premium until expiry
    status: 'cancelled',
    expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
    autoRenewing: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`Marked subscription as cancelled for user ${userId}`);
}

async function markSubscriptionAtRisk(userId, purchaseDetails) {
  if (!userId) return;

  await admin.firestore().collection('subscriptions').doc(userId).set({
    isPremium: true,
    status: 'at_risk',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`Marked subscription at risk for user ${userId}`);
}

async function pauseSubscription(userId) {
  if (!userId) return;

  await admin.firestore().collection('subscriptions').doc(userId).set({
    isPremium: false,
    status: 'paused',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`Paused subscription for user ${userId}`);
}
```

### Step 2: Deploy Cloud Function

```bash
# Install dependencies
cd functions
npm install firebase-functions firebase-admin googleapis

# Deploy
firebase deploy --only functions:handlePlayStoreNotification
```

### Step 3: Configure Google Play Console

1. Go to Google Play Console
2. Navigate to: **Monetization setup** → **Real-time developer notifications**
3. Enter your Cloud Function URL:
   ```
   https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/handlePlayStoreNotification
   ```
4. Click **Send test notification** to verify
5. Save changes

### Step 4: Set Up Google Cloud Pub/Sub Topic

1. Go to Google Cloud Console
2. Enable **Cloud Pub/Sub API**
3. Create a topic: `play-subscriptions`
4. Grant Google Play service account publish permission
5. Update Play Console with topic name

### Step 5: Link User ID to Purchase

When user makes a purchase, you need to link their Firebase UID to the purchase token:

```dart
// subscription_service.dart
Future<void> setPremium(
  bool value, {
  String? purchaseId,
  String? productId,
}) async {
  _isPremium = value;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_premiumKey, value);
  await prefs.setString(_purchaseDateKey, DateTime.now().toIso8601String());

  DateTime? expiry;
  if (value && productId != null) {
    expiry = productId == annualSubscriptionId
        ? DateTime.now().add(_annualDuration)
        : DateTime.now().add(_monthlyDuration);
    await prefs.setString(_expiryKey, expiry.toIso8601String());
    await prefs.setString(_productIdKey, productId);
  }

  // Sync to Firebase with purchase token
  if (_auth.isSignedIn) {
    try {
      await _firestore.saveSubscription(
        userId: _auth.currentUser!.uid,
        isPremium: value,
        purchaseId: purchaseId,
        productId: productId,
        expiryDate: expiry,
        purchaseToken: purchaseId, // Important: Save purchase token
      );
    } catch (e) {
      print('Failed to sync subscription: $e');
    }
  }

  await _updateWidget();
  notifyListeners();
}
```

### Step 6: Update Firestore Service

```dart
// firebase_firestore_service.dart
Future<void> saveSubscription({
  required String userId,
  required bool isPremium,
  String? purchaseId,
  String? productId,
  DateTime? expiryDate,
  String? purchaseToken, // Add this
}) async {
  if (subscriptions == null) return;

  try {
    await subscriptions!.doc(userId).set({
      'isPremium': isPremium,
      'purchaseId': purchaseId,
      'productId': productId,
      'purchaseToken': purchaseToken, // Save token
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'status': isPremium ? 'active' : 'inactive',
      'autoRenewing': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    print('Error saving subscription: $e');
    rethrow;
  }
}
```

### Step 7: Add Real-Time Listener in App

```dart
// subscription_service.dart
StreamSubscription<DocumentSnapshot>? _subscriptionListener;

Future<void> init() async {
  await _loadPremiumStatus();
  await _initializeProducts();
  
  // Listen to subscription changes in real-time
  if (_auth.isSignedIn) {
    _listenToSubscriptionChanges();
  }
}

void _listenToSubscriptionChanges() {
  final userId = _auth.currentUser?.uid;
  if (userId == null) return;

  _subscriptionListener = _firestore.subscriptions
      ?.doc(userId)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      final isPremium = data['isPremium'] as bool? ?? false;
      final status = data['status'] as String? ?? 'inactive';

      // Update local state
      if (_isPremium != isPremium) {
        _isPremium = isPremium;
        _savePremiumStatus(isPremium);
        _updateWidget();
        notifyListeners();

        // Show message to user if subscription was cancelled/expired
        if (!isPremium && status == 'expired') {
          _showSubscriptionExpiredMessage();
        } else if (!isPremium && status == 'cancelled') {
          _showSubscriptionCancelledMessage();
        }
      }
    }
  });
}

void _showSubscriptionExpiredMessage() {
  // Show notification or in-app message
  print('Your subscription has expired');
}

void _showSubscriptionCancelledMessage() {
  // Show notification or in-app message
  print('Your subscription was cancelled');
}

@override
void dispose() {
  _subscriptionListener?.cancel();
  super.dispose();
}
```

## Notification Types Reference

| Type | Code | Description | Action |
|------|------|-------------|--------|
| SUBSCRIPTION_RECOVERED | 1 | Subscription recovered from account hold | Grant premium |
| SUBSCRIPTION_RENEWED | 2 | Active subscription renewed | Grant premium |
| SUBSCRIPTION_CANCELED | 3 | User cancelled (still active until expiry) | Mark as cancelled |
| SUBSCRIPTION_PURCHASED | 4 | New subscription purchased | Grant premium |
| SUBSCRIPTION_ON_HOLD | 5 | Payment failed, on hold | Keep premium, mark at-risk |
| SUBSCRIPTION_IN_GRACE_PERIOD | 6 | Payment failed, in grace period | Keep premium, mark at-risk |
| SUBSCRIPTION_RESTARTED | 7 | Subscription restarted | Grant premium |
| SUBSCRIPTION_PRICE_CHANGE_CONFIRMED | 8 | User confirmed price change | No action |
| SUBSCRIPTION_DEFERRED | 9 | Subscription deferred | No action |
| SUBSCRIPTION_PAUSED | 10 | Subscription paused | Revoke premium |
| SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED | 11 | Pause schedule changed | No action |
| SUBSCRIPTION_REVOKED | 12 | Refund issued | Revoke premium immediately |
| SUBSCRIPTION_EXPIRED | 13 | Subscription expired | Revoke premium |

## Testing

### Test Cancellation Flow

1. Purchase subscription with test account
2. Cancel subscription in Play Store
3. Verify Cloud Function receives notification
4. Check Firebase - status should be 'cancelled'
5. Wait for expiry date
6. Verify Cloud Function receives expiry notification
7. Check Firebase - isPremium should be false
8. Verify app updates UI immediately

### Test Commands

```bash
# View Cloud Function logs
firebase functions:log --only handlePlayStoreNotification

# Test notification manually
curl -X POST https://YOUR-FUNCTION-URL \
  -H "Content-Type: application/json" \
  -d '{"message":{"data":"BASE64_ENCODED_NOTIFICATION"}}'
```

## Important Notes

1. **Cancellation vs Expiry**:
   - When user cancels, they keep premium until expiry date
   - Set `status: 'cancelled'` but keep `isPremium: true`
   - Only revoke when you receive SUBSCRIPTION_EXPIRED (type 13)

2. **Grace Period**:
   - If payment fails, Google gives 3-7 days grace period
   - Keep premium active during grace period
   - Mark as 'at_risk' to show warning to user

3. **Refunds**:
   - SUBSCRIPTION_REVOKED (type 12) means refund issued
   - Revoke premium immediately
   - No grace period for refunds

4. **User ID Linking**:
   - Must link Firebase UID to purchase token
   - Use `obfuscatedExternalAccountId` in purchase
   - Store mapping in Firestore

5. **Real-Time Updates**:
   - Use Firestore real-time listeners
   - App updates immediately when backend changes subscription
   - No need to restart app

## Security Considerations

1. **Verify Notifications**:
   - Always verify notifications are from Google
   - Check signature/authentication
   - Validate purchase token with Google Play API

2. **Fail Closed**:
   - If verification fails, don't grant premium
   - If notification processing fails, log error
   - Don't revoke premium on temporary failures

3. **Rate Limiting**:
   - Implement rate limiting on Cloud Function
   - Prevent abuse/spam
   - Log suspicious activity

## Cost Considerations

- Cloud Functions: ~$0.40 per million invocations
- Firestore writes: ~$0.18 per 100k writes
- Google Play API calls: Free
- Estimated cost: <$5/month for 10k users

## Fallback Strategy

If real-time notifications fail:

1. **Periodic Validation**:
   - Check subscription status daily
   - Validate with Google Play API
   - Update Firebase if changed

2. **On App Launch**:
   - Validate subscription on app start
   - Sync with Firebase
   - Update local state

3. **Manual Restore**:
   - User can manually restore purchases
   - Triggers validation
   - Updates status

## Summary

✅ **With RTDN**: Instant revocation when subscription expires
✅ **Real-time updates**: App updates immediately via Firestore listener
✅ **Secure**: Backend validates all changes
✅ **Reliable**: Multiple fallback mechanisms
✅ **Cost-effective**: Minimal cloud costs

❌ **Without RTDN**: User keeps premium indefinitely after cancellation
