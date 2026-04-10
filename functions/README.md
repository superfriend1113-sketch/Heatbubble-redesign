# HeatBubble Cloud Functions

This directory contains Cloud Functions for the HeatBubble app.

## Functions

### handlePlayStoreNotification

Receives and processes Google Play Real-Time Developer Notifications for subscription events.

**Endpoint**: `https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/handlePlayStoreNotification`

**Events Handled**:
- Subscription purchased
- Subscription renewed
- Subscription cancelled
- Subscription expired
- Subscription paused
- Subscription revoked (refund)
- Payment issues (grace period, on hold)

**Flow**:
1. Receives notification from Google Play
2. Decodes base64-encoded data
3. Verifies purchase with Google Play API
4. Updates Firestore subscription document
5. App receives real-time update via Firestore listener

## Setup

### Install Dependencies

```bash
npm install
```

### Deploy

```bash
# From project root
firebase deploy --only functions

# Or from functions directory
cd functions
npm run deploy
```

### View Logs

```bash
# From project root
firebase functions:log --only handlePlayStoreNotification

# Stream logs in real-time
firebase functions:log --only handlePlayStoreNotification --follow
```

## Configuration

### Required APIs

Enable these in Google Cloud Console:
- Cloud Functions API
- Google Play Android Developer API
- Cloud Pub/Sub API

### Service Account Permissions

Your Firebase service account needs:
- Cloud Functions Developer
- Pub/Sub Publisher
- Pub/Sub Subscriber

### Play Console Setup

1. Go to Play Console → Monetization setup → Real-time developer notifications
2. Enter function URL
3. Send test notification to verify
4. Save

## Testing

### Test Notification

```bash
# Send test notification from Play Console
# Check logs for: "Test notification received - setup successful!"
firebase functions:log --only handlePlayStoreNotification
```

### Test with Real Subscription

1. Purchase subscription with test account
2. Cancel subscription in Play Store
3. Check logs for notification type 3 (SUBSCRIPTION_CANCELED)
4. Check Firestore - status should be 'cancelled'
5. Wait for expiry
6. Check logs for notification type 13 (SUBSCRIPTION_EXPIRED)
7. Check Firestore - isPremium should be false

## Notification Types

| Type | Code | Description |
|------|------|-------------|
| SUBSCRIPTION_RECOVERED | 1 | Recovered from account hold |
| SUBSCRIPTION_RENEWED | 2 | Auto-renewed |
| SUBSCRIPTION_CANCELED | 3 | User cancelled |
| SUBSCRIPTION_PURCHASED | 4 | New purchase |
| SUBSCRIPTION_ON_HOLD | 5 | Payment failed, on hold |
| SUBSCRIPTION_IN_GRACE_PERIOD | 6 | Payment failed, grace period |
| SUBSCRIPTION_RESTARTED | 7 | Reactivated |
| SUBSCRIPTION_PAUSED | 10 | User paused |
| SUBSCRIPTION_REVOKED | 12 | Refund issued |
| SUBSCRIPTION_EXPIRED | 13 | Expired |

## Firestore Structure

### subscriptions/{userId}

```json
{
  "isPremium": true,
  "productId": "heatbubble_premium_monthly",
  "purchaseToken": "abc123...",
  "expiryDate": "2026-05-08T12:00:00Z",
  "status": "active",
  "autoRenewing": true,
  "updatedAt": "2026-04-08T12:00:00Z"
}
```

### Status Values

- `active` - Subscription is active and auto-renewing
- `cancelled` - User cancelled but still has access until expiry
- `expired` - Subscription has expired, no premium access
- `paused` - User paused subscription
- `grace_period` - Payment failed, in grace period
- `on_hold` - Payment failed, on hold
- `inactive` - No subscription

## Troubleshooting

### Function not receiving notifications

1. Check function URL in Play Console
2. Verify function is deployed: `firebase functions:list`
3. Check logs for errors: `firebase functions:log`
4. Verify APIs are enabled
5. Check service account permissions

### Purchase verification fails

1. Enable Google Play Android Developer API
2. Verify service account has correct permissions
3. Check package name is correct: `com.heatbubble.app`

### User ID not found

1. Ensure user is signed in before purchase
2. Check `applicationUserName` is passed during purchase
3. Verify Firebase UID is valid

## Cost

Estimated cost for 10,000 users:
- Cloud Functions: ~$0.20/month
- Firestore writes: ~$0.09/month
- Total: ~$0.30/month

## Security

✅ Verifies notifications are from Google
✅ Validates purchase tokens with Google Play API
✅ Fails closed (doesn't grant premium on error)
✅ Backend-only writes to subscriptions

## Support

For issues:
1. Check logs: `firebase functions:log`
2. Check Firestore data in Firebase Console
3. Review RTDN_DEPLOYMENT_GUIDE.md
4. Contact: heatbubble2026@gmail.com
