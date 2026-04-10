# Real-Time Developer Notifications (RTDN) Deployment Guide

## Overview

This guide walks you through deploying the Google Play Real-Time Developer Notifications system for HeatBubble. This enables automatic subscription cancellation detection and real-time premium status updates.

## What You've Implemented

✅ Cloud Function backend (`functions/index.js`)
✅ Real-time Firestore listener in app (`subscription_service.dart`)
✅ Purchase token storage (`firebase_firestore_service.dart`)
✅ User ID linking during purchase (`subscription_service.dart`)
✅ Auto-start listener after sign-in (login/signup screens)

## Deployment Steps

### Step 1: Install Cloud Functions Dependencies

```bash
cd functions
npm install
```

This installs:
- `firebase-functions` - Cloud Functions SDK
- `firebase-admin` - Firebase Admin SDK
- `googleapis` - Google Play Developer API client

### Step 2: Enable Required APIs

Go to [Google Cloud Console](https://console.cloud.google.com/) and enable:

1. **Cloud Functions API**
   - Navigate to: APIs & Services → Library
   - Search for "Cloud Functions API"
   - Click "Enable"

2. **Google Play Android Developer API**
   - Search for "Google Play Android Developer API"
   - Click "Enable"

3. **Cloud Pub/Sub API**
   - Search for "Cloud Pub/Sub API"
   - Click "Enable"

### Step 3: Set Up Service Account Permissions

1. Go to [IAM & Admin → Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)

2. Find your Firebase service account (usually `firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com`)

3. Click "Edit" (pencil icon)

4. Add these roles:
   - **Cloud Functions Developer**
   - **Pub/Sub Publisher**
   - **Pub/Sub Subscriber**

5. Click "Save"

### Step 4: Link Google Play Console to Firebase Project

1. Go to [Google Play Console](https://play.google.com/console)

2. Select your app (HeatBubble)

3. Navigate to: **Setup → API access**

4. Click "Link" next to your Firebase project

5. Grant the required permissions

### Step 5: Deploy Cloud Function

```bash
# From project root
firebase deploy --only functions
```

This will:
- Upload your function code
- Create the function endpoint
- Return the function URL

**Save the URL!** It will look like:
```
https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/handlePlayStoreNotification
```

### Step 6: Configure Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)

2. Select your app (HeatBubble)

3. Navigate to: **Monetization setup → Real-time developer notifications**

4. Enter your Cloud Function URL from Step 5

5. Click **Send test notification** to verify

6. You should see "Test notification received" in Cloud Function logs

7. Click **Save**

### Step 7: Set Up Cloud Pub/Sub Topic (Optional but Recommended)

For better reliability, use Pub/Sub instead of direct HTTP:

1. Go to [Cloud Pub/Sub Console](https://console.cloud.google.com/cloudpubsub)

2. Click "Create Topic"

3. Name it: `play-subscriptions`

4. Click "Create"

5. Grant Google Play service account publish permission:
   - Click on the topic
   - Click "Permissions"
   - Add member: `google-play-developer-notifications@system.gserviceaccount.com`
   - Role: **Pub/Sub Publisher**
   - Click "Save"

6. Update Play Console with topic name:
   - Go back to Play Console → Monetization setup → Real-time developer notifications
   - Enter topic name: `projects/YOUR-PROJECT-ID/topics/play-subscriptions`
   - Click "Save"

### Step 8: Update Firestore Security Rules

Add subscription collection rules to `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Subscriptions - read-only for users, write-only for backend
    match /subscriptions/{userId} {
      allow read: if isOwner(userId);
      allow write: if false; // Only Cloud Functions can write
    }
    
    // ... other rules
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

### Step 9: Test the Setup

#### Test 1: Send Test Notification

1. Go to Play Console → Monetization setup → Real-time developer notifications
2. Click "Send test notification"
3. Check Cloud Function logs:
   ```bash
   firebase functions:log --only handlePlayStoreNotification
   ```
4. You should see: "Test notification received - setup successful!"

#### Test 2: Test with Real Subscription

1. Purchase subscription with test account (use license testing)
2. Check Firestore - subscription document should be created
3. Cancel subscription in Play Store
4. Check Cloud Function logs - should receive type 3 (SUBSCRIPTION_CANCELED)
5. Check Firestore - status should be 'cancelled', isPremium still true
6. Wait for expiry date (or use test subscription with short duration)
7. Check Cloud Function logs - should receive type 13 (SUBSCRIPTION_EXPIRED)
8. Check Firestore - isPremium should be false
9. Check app - premium features should be revoked immediately

### Step 10: Monitor in Production

#### View Cloud Function Logs

```bash
# View recent logs
firebase functions:log --only handlePlayStoreNotification

# Stream logs in real-time
firebase functions:log --only handlePlayStoreNotification --follow
```

#### Monitor in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to: Functions → Dashboard
4. View invocations, errors, and execution time

#### Set Up Alerts

1. Go to Firebase Console → Functions
2. Click on `handlePlayStoreNotification`
3. Click "Metrics" tab
4. Click "Create Alert"
5. Set conditions:
   - Error rate > 5%
   - Execution time > 10 seconds
6. Add your email for notifications

## Notification Types Reference

| Type | Code | Event | Action |
|------|------|-------|--------|
| SUBSCRIPTION_RECOVERED | 1 | Recovered from hold | Grant premium |
| SUBSCRIPTION_RENEWED | 2 | Auto-renewed | Grant premium |
| SUBSCRIPTION_CANCELED | 3 | User cancelled | Mark cancelled (keep premium until expiry) |
| SUBSCRIPTION_PURCHASED | 4 | New purchase | Grant premium |
| SUBSCRIPTION_ON_HOLD | 5 | Payment failed | Keep premium, mark at-risk |
| SUBSCRIPTION_IN_GRACE_PERIOD | 6 | Payment failed | Keep premium, mark at-risk |
| SUBSCRIPTION_RESTARTED | 7 | Reactivated | Grant premium |
| SUBSCRIPTION_PAUSED | 10 | User paused | Revoke premium |
| SUBSCRIPTION_REVOKED | 12 | Refund issued | Revoke premium immediately |
| SUBSCRIPTION_EXPIRED | 13 | Expired | Revoke premium |

## Troubleshooting

### Issue: Function not receiving notifications

**Check:**
1. Function URL is correct in Play Console
2. Function is deployed successfully
3. APIs are enabled (Cloud Functions, Play Developer API)
4. Service account has correct permissions

**Fix:**
```bash
# Redeploy function
firebase deploy --only functions

# Check function status
firebase functions:list

# View logs for errors
firebase functions:log --only handlePlayStoreNotification
```

### Issue: Purchase verification fails

**Check:**
1. Google Play Android Developer API is enabled
2. Service account has correct permissions
3. Package name is correct (`com.heatbubble.app`)

**Fix:**
- Go to Cloud Console → APIs & Services → Credentials
- Verify service account has "Google Play Android Developer" role

### Issue: User ID not found in purchase

**Check:**
1. `applicationUserName` is passed during purchase
2. User is signed in before purchase
3. Firebase UID is valid

**Fix:**
- Ensure authentication is required before purchase (already implemented)
- Check `_startSubscription` method passes `applicationUserName`

### Issue: App not updating in real-time

**Check:**
1. Firestore listener is started after sign-in
2. User is signed in
3. Internet connection is active

**Fix:**
- Call `_subscription.startListening()` after sign-in (already implemented)
- Check Firestore rules allow read access
- Verify subscription document exists in Firestore

## Cost Estimates

Based on 10,000 active users:

| Service | Usage | Cost |
|---------|-------|------|
| Cloud Functions | ~50k invocations/month | $0.20 |
| Firestore Writes | ~50k writes/month | $0.09 |
| Firestore Reads | ~500k reads/month | $0.18 |
| Cloud Pub/Sub | ~50k messages/month | $0.02 |
| **Total** | | **~$0.50/month** |

For 100,000 users: ~$5/month

## Security Best Practices

✅ **Implemented:**
- Verify notifications are from Google (Pub/Sub format)
- Validate purchase tokens with Google Play API
- Fail closed (don't grant premium on verification failure)
- Backend-only writes to subscription collection

🔒 **Additional Recommendations:**
1. Enable Firebase App Check to prevent API abuse
2. Add rate limiting to Cloud Function
3. Monitor for suspicious activity
4. Set up budget alerts in Google Cloud Console

## Next Steps

After deployment:

1. ✅ Test with test account
2. ✅ Monitor logs for first week
3. ✅ Set up alerts for errors
4. ✅ Document any issues
5. ✅ Update PRODUCTION_IMPROVEMENTS.md

## Support

If you encounter issues:

1. Check Cloud Function logs: `firebase functions:log`
2. Check Firestore data in Firebase Console
3. Check Play Console for notification delivery status
4. Review this guide for missed steps

## Summary

✅ **What This Achieves:**
- Instant revocation when subscription expires
- Real-time updates across all devices
- Handles all subscription lifecycle events
- Secure backend validation
- Cost-effective (<$5/month for 10k users)

✅ **What You Can Now Do:**
- User cancels subscription → App knows immediately
- Subscription expires → Premium revoked automatically
- Payment fails → User notified to update payment
- Refund issued → Premium revoked instantly
- Cross-device sync → All devices update in real-time

---

**Last Updated**: Version 1.0.8+10
**Status**: Ready for deployment
