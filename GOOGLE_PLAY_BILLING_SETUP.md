# Google Play Billing Setup Guide

## Step 1: Create Products in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app (HeatBubble)
3. Navigate to **Monetization → In-app products**

### Create One-Time Purchase:
- Product ID: `heatbubble_premium_onetime`
- Name: HeatBubble Premium (Lifetime)
- Description: Unlock all premium features forever
- Price: $2.99 USD
- Status: Active

### Create Monthly Subscription:
- Product ID: `heatbubble_premium_monthly`
- Name: HeatBubble Premium (Monthly)
- Description: Monthly access to all premium features
- Price: $1.99 USD/month
- Billing period: 1 month
- Status: Active

## Step 2: Test Your In-App Purchases

### Add Test Accounts:
1. Go to **Setup → License testing**
2. Add your Gmail account as a license tester
3. Save changes

### Testing:
- Test accounts can make purchases without being charged
- Purchases will show as "Test purchase" in the app
- You can test the full purchase flow

## Step 3: Product IDs in Code

The product IDs are already configured in `lib/services/subscription_service.dart`:

```dart
static const String oneTimePurchaseId = 'heatbubble_premium_onetime';
static const String monthlySubscriptionId = 'heatbubble_premium_monthly';
```

## Step 4: Build and Test

```bash
# Build release APK
flutter build apk --release

# Or build App Bundle for Play Store
flutter build appbundle --release
```

Upload to Google Play Console (Internal Testing track) to test real billing.

## Features Implemented

✅ Real-time purchase processing
✅ Purchase stream listener
✅ Automatic purchase completion
✅ Restore purchases functionality
✅ Error handling with user feedback
✅ Loading states during purchase
✅ Firebase sync after purchase
✅ Beautiful animated UI
✅ Product price fetching from Play Store

## Testing Checklist

- [ ] Products created in Play Console
- [ ] Test account added
- [ ] App uploaded to Internal Testing
- [ ] One-time purchase works
- [ ] Monthly subscription works
- [ ] Restore purchases works
- [ ] Premium features unlock after purchase
- [ ] Firebase sync works after purchase
