# Google Play Billing Setup Guide

## Important: Individual Developer Account

Since your client is an individual (not a business), here's what you need to know:

### Account Type
- ✅ **Personal/Individual Account** - Perfect for solo developers
- ❌ No business registration needed
- ✅ Can still sell apps and in-app purchases
- ✅ Lower barrier to entry ($25 one-time fee)

### Limitations to Consider
- ⚠️ **Payment Processing**: Individual accounts can accept payments, but:
  - Need to provide tax information (W-9 for US, tax forms for other countries)
  - Google takes 15% commission (first $1M revenue) then 30%
  - Payments go to individual's bank account
- ⚠️ **Business Features**: Some features require organization account:
  - Multiple user access
  - Company branding
  - Advanced analytics

### Recommendation
For a solo client just starting out, an **Individual Account is fine**. They can always upgrade to Organization account later if needed.

---

## Step 1: Create Google Play Developer Account

### For Your Client (Individual Account):

1. Go to [Google Play Console](https://play.google.com/console/signup)
2. Sign in with their Gmail account
3. Choose **"Personal"** account type (not Organization)
4. Pay $25 one-time registration fee
5. Complete developer profile:
   - Full name
   - Email address
   - Phone number
   - Country
6. Accept Developer Distribution Agreement
7. Set up payment profile:
   - Add bank account for receiving payments
   - Provide tax information (required for payments)

**Note**: Account approval can take 24-48 hours.

---

## Step 2: Create Your App in Play Console

1. Click **"Create app"**
2. Fill in app details:
   - App name: HeatBubble
   - Default language: English
   - App type: App
   - Free or Paid: Free (with in-app purchases)
3. Complete all required sections:
   - App content
   - Privacy policy (required for apps with in-app purchases)
   - Target audience
   - Content rating

---

## Step 3: Create In-App Products

1. Navigate to **Monetization → In-app products**
2. Click **"Create product"**

### Create One-Time Purchase:
- Product ID: `heatbubble_premium_onetime`
- Name: HeatBubble Premium (Lifetime)
- Description: Unlock all premium features forever - no ads, hourly charts, custom alerts, cloud backup
- Price: $2.99 USD
- Status: Active

### Create Monthly Subscription:
- Product ID: `heatbubble_premium_monthly`
- Name: HeatBubble Premium (Monthly)
- Description: Monthly access to all premium features - cancel anytime
- Price: $1.99 USD/month
- Billing period: 1 month
- Free trial: Optional (e.g., 7 days)
- Status: Active

**Important**: Products must be activated before they appear in the app!

---

## Step 4: Set Up Testing

### Add License Testers:
1. Go to **Setup → License testing**
2. Add Gmail accounts (yours and client's):
   - Your email: superfriend1113@gmail.com
   - Client's email: [their Gmail]
3. Response: **Licensed**
4. Save changes

### Benefits of License Testing:
- ✅ Test purchases without being charged
- ✅ Instant purchase approval
- ✅ Can test full purchase flow
- ✅ Shows "Test purchase" badge in app

---

## Step 5: Upload App for Testing

### Build the App:
```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Upload to Internal Testing:
1. Go to **Testing → Internal testing**
2. Create new release
3. Upload `app-release.aab`
4. Add release notes
5. Review and rollout

### Add Testers:
1. Create email list with test accounts
2. Share testing link with testers
3. Testers can install from Play Store

---

## Step 6: Product IDs in Code

Already configured in `lib/services/subscription_service.dart`:

```dart
static const String oneTimePurchaseId = 'heatbubble_premium_onetime';
static const String monthlySubscriptionId = 'heatbubble_premium_monthly';
```

**Important**: Product IDs in code MUST match exactly with Play Console!

---

## Step 7: Tax & Payment Setup

### For Individual Developers:

1. **US Developers**:
   - Fill out W-9 form
   - Provide SSN or EIN
   - Google will send 1099 tax form annually

2. **Non-US Developers**:
   - Fill out W-8BEN form
   - Provide tax identification number
   - May have tax withholding (varies by country)

3. **Bank Account**:
   - Add bank account for receiving payments
   - Payments processed monthly (if > $10 threshold)
   - 15% commission on first $1M revenue/year
   - 30% commission after $1M

---

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

---

## Testing Checklist

### Before Launch:
- [ ] Google Play Developer account created (Individual)
- [ ] App created in Play Console
- [ ] Privacy policy URL added
- [ ] Products created in Play Console
- [ ] Products activated (Status: Active)
- [ ] License testers added
- [ ] App uploaded to Internal Testing
- [ ] Test account can install app
- [ ] One-time purchase works
- [ ] Monthly subscription works
- [ ] Restore purchases works
- [ ] Premium features unlock after purchase
- [ ] Firebase sync works after purchase
- [ ] Tax information submitted
- [ ] Bank account added for payments

### Common Issues:

**"Product not found" error:**
- ✅ Check product IDs match exactly
- ✅ Ensure products are Active in Play Console
- ✅ Wait 2-4 hours after creating products
- ✅ App must be uploaded to at least Internal Testing

**"Purchase failed" error:**
- ✅ Ensure test account is added to License testing
- ✅ Check internet connection
- ✅ Verify Google Play Services is updated

**"Item already owned" error:**
- ✅ Use "Restore purchases" to clear
- ✅ Or consume the purchase in Play Console

---

## Cost Breakdown for Client

### One-Time Costs:
- Google Play Developer Account: $25 (one-time)
- Firebase: Free tier (sufficient for starting)

### Ongoing Costs:
- Google Play Commission: 15% of revenue (first $1M/year)
- Firebase: Free tier, then pay-as-you-go if exceeds limits
- Firestore: ~$81/month for 1M users (with our optimization)

### Revenue Potential:
- If 1% of users buy premium at $2.99:
  - 10,000 users = 100 purchases = $299 revenue
  - After 15% commission = $254.15 net
- Monthly subscriptions provide recurring revenue

---

## Support Resources

- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [In-App Billing Documentation](https://developer.android.com/google/play/billing)
- [Tax Information](https://support.google.com/googleplay/android-developer/answer/138000)
- [Individual vs Organization Account](https://support.google.com/googleplay/android-developer/answer/6112435)
