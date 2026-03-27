# Google Play Billing Setup Guide

## Subscription Model (Client Requirements)

| Plan | Price | Billing | Trial |
|------|-------|---------|-------|
| **Monthly** | $1.99 / month | Auto-renews monthly | 7-day free trial (first download only) |
| **Annual** | $19.99 / year | Auto-renews every year | 7-day free trial (first download only) |

> **Annual saves ~17%** vs monthly ($23.88/yr vs $19.99/yr) — good upsell angle in the UI.

> **Trial rule**: The 7-day free trial is granted **once per Google account**, on first subscription only. If the user cancels and re-subscribes, no second trial is given (Google enforces this automatically).

---

## Important: Individual Developer Account

Since your client is an individual (not a business), here's what you need to know:

### Account Type
- ✅ **Personal/Individual Account** — Perfect for solo developers
- ❌ No business registration needed
- ✅ Can still sell apps and in-app purchases
- ✅ Lower barrier to entry ($25 one-time fee)

### Limitations to Consider
- ⚠️ **Payment Processing**: Individual accounts can accept payments, but:
  - Need to provide tax information (W-9 for US, tax forms for other countries)
  - Google takes **15% commission** (first $1M revenue/year), then **30%**
  - Payments go to individual's bank account
- ⚠️ **Business Features**: Some features require an organization account:
  - Multiple user access
  - Company branding / advanced analytics

### Recommendation
For a solo client just starting out, an **Individual Account is fine**. They can upgrade to an Organization account later.

---

## Step 1: Create Google Play Developer Account

1. Go to [Google Play Console](https://play.google.com/console/signup)
2. Sign in with their Gmail account
3. Choose **"Personal"** account type (not Organization)
4. Pay **$25 one-time** registration fee
5. Complete developer profile: full name, email, phone, country
6. Accept Developer Distribution Agreement
7. Set up payment profile:
   - Add bank account for receiving payments
   - Provide tax information (required before first payout)

> **Note**: Account approval can take 24–48 hours.

---

## Step 2: Create Your App in Play Console

1. Click **"Create app"**
2. Fill in app details:
   - App name: **HeatBubble**
   - Default language: English
   - App type: App
   - Free or Paid: **Free** (with in-app subscriptions)
3. Complete all required sections:
   - App content
   - Privacy policy URL (required when selling subscriptions)
   - Target audience
   - Content rating

---

## Step 3: Set Up Merchant Account ← YOU ARE HERE

> This is exactly what the **"Monetize with Play → Get started"** button sets up.
> **You cannot create subscriptions or in-app products until this is complete.**

### What to do:

1. On the **Monetize with Play** screen, click **"Get started →"**
2. You'll be taken to the **Google Payments merchant account** setup
3. Fill in the required information:

| Field | What to enter |
|-------|---------------|
| **Legal name** | Your full legal name (individual account) |
| **Country** | Your country of residence |
| **Business type** | Individual / Sole trader |
| **Address** | Your home/business address |
| **Phone number** | Active phone number |
| **Tax information** | W-9 (US) or W-8BEN (non-US) |
| **Bank account** | Where Google sends payouts |

4. Click **"Create merchant account"**
5. Wait for approval — usually **instant to 24 hours**

> ✅ Once approved, the "Products" section appears in the left sidebar under **Monetize with Play** and you can create subscriptions.

> ⚠️ **Indian developers**: Use your PAN number for tax ID. Bank account must be an Indian bank account (IFSC + account number). Payouts come via wire transfer in USD, converted to INR by your bank.

---

## Step 4: Create Subscription Products

> ✅ **Merchant account approved!** You can now see **Products → Subscriptions** in the left sidebar.

---

## How to reach the Subscriptions page

In the left sidebar (you can already see this):
**Monetize with Play → Products → Subscriptions**

Click **"Subscriptions"** → then click **"Create subscription"** (blue button, top right).

---

### Subscription 1 of 2 — Monthly ($1.99/month)

#### Part A — Basic Info

| Field | What to type |
|-------|-------------|
| **Product ID** | `heatbubble_premium_monthly` |
| **Name** | `HeatBubble Premium – Monthly` |
| **Description** | `Full access to all premium features. Cancel anytime.` |

Click **"Save"** (do NOT click "Add base plan" yet).

#### Part B — Add Base Plan

After saving, click **"Add base plan"**:

| Field | Value |
|-------|-------|
| **Base plan ID** | `monthly-base` |
| **Renewal type** | Auto-renewing |
| **Billing period** | **Monthly (every 1 month)** |
| **Price** | Click "Set price" → enter **$1.99** for United States → click "Set price for other countries" → let Google auto-convert |
| **Status** | Active |

Click **"Save"**.

#### Part C — Add Free Trial Offer

After the base plan is saved, click **"Add offer"**:

| Field | Value |
|-------|-------|
| **Offer ID** | `monthly-trial` |
| **Offer type** | **Free trial** |
| **Duration** | **7 days** |
| **Eligibility** | **New subscribers** (one trial per Google account — automatic) |
| **Base plans** | Select `monthly-base` |

Click **"Save"** → then click **"Activate"** on both the offer and the base plan.

> ✅ The base plan should show **"Active"** badge when done.

---

### Subscription 2 of 2 — Annual ($19.99/year)

Go back to **Subscriptions** → **"Create subscription"** again.

#### Part A — Basic Info

| Field | What to type |
|-------|-------------|
| **Product ID** | `heatbubble_premium_annual` |
| **Name** | `HeatBubble Premium – Annual` |
| **Description** | `Full year access to all premium features. Auto-renews yearly. Save 17% vs monthly.` |

Click **"Save"**.

#### Part B — Add Base Plan

Click **"Add base plan"**:

| Field | Value |
|-------|-------|
| **Base plan ID** | `annual-base` |
| **Renewal type** | Auto-renewing |
| **Billing period** | **Yearly (every 12 months)** |
| **Price** | Click "Set price" → enter **$19.99** for United States → auto-convert others |
| **Status** | Active |

Click **"Save"**.

#### Part C — Add Free Trial Offer

Click **"Add offer"**:

| Field | Value |
|-------|-------|
| **Offer ID** | `annual-trial` |
| **Offer type** | **Free trial** |
| **Duration** | **7 days** |
| **Eligibility** | **New subscribers** |
| **Base plans** | Select `annual-base` |

Click **"Save"** → **"Activate"** both the offer and base plan.

---

> ⚠️ **Important notes:**
> - Product IDs are **permanent** — you cannot change them after creation
> - Wait **2–4 hours** after activating before products appear in the live app
> - The annual plan **auto-renews every 12 months** at $19.99 — users must cancel to stop it
> - Both 7-day trials are **one per Google account** — Google enforces this automatically

---

## Step 5: Update Product IDs in Code

Edit `lib/services/subscription_service.dart`:

```dart
// ── Subscription product IDs ── must match Play Console exactly
static const String monthlySubscriptionId = 'heatbubble_premium_monthly';
static const String annualSubscriptionId  = 'heatbubble_premium_annual';

// Remove / leave unused:
// static const String oneTimePurchaseId = 'heatbubble_premium_onetime';
```

> The `oneTimePurchaseId` (lifetime purchase) is no longer part of the offering. Remove it from the UI if you haven't already.

---

## Step 6: Free Trial Logic

Google Play handles the 7-day trial **automatically**:

- Trial starts when the user confirms the subscription for the first time
- No payment is taken during the 7-day window
- On day 8, the user is charged ($1.99 or $19.99)
- If user cancels before day 8 → never charged, access ends when trial ends
- **Second trial**: Google blocks a second free trial on the same Google account for the same subscription — you don't need to enforce this in code

### In-app trial awareness (Flutter side)

When the user is in trial, `in_app_purchase` sets the purchase state. You can detect it:

```dart
// In SubscriptionService — check if user has a trial-period purchase
bool get isInTrial {
  // Purchase details from Google Play include introductoryPriceAmountMicros
  // When in trial, the subscription is active but not yet charged
  return _currentPurchase?.status == PurchaseStatus.purchased &&
         _trialActive == true;
}
```

> For simplicity, treat trial users as premium (full access). They've committed to subscribe; just haven't been charged yet.

---

## Step 7: Set Up Testing

### Add License Testers:
1. Go to **Setup → License testing**
2. Add Gmail accounts:
   - Developer email: superfriend1113@gmail.com
   - Client's Gmail: [their Gmail]
3. Response: **Licensed**
4. Save changes

### Benefits of License Testing:
- ✅ Test purchases without real charges
- ✅ Subscription periods are accelerated (1 month = 5 minutes)
- ✅ Free trial is skipped for licence testers (immediate billing cycle start)
- ✅ Can cancel / resubscribe multiple times for testing

---

## Step 8: Upload App for Testing

```bash
# Build App Bundle (required for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

1. Go to **Testing → Internal testing**
2. Create new release → upload `app-release.aab`
3. Add release notes
4. Share testing opt-in link with testers

---

## Step 9: Tax & Payment Setup

### For Individual Developers:

1. **US Developers**: Fill out W-9 (SSN or EIN). Google sends 1099 annually.
2. **Non-US Developers**: Fill out W-8BEN + tax ID. Withholding varies by country.
3. **Bank Account**: Add bank account → payments processed monthly (min $10 threshold).

---

## Revenue Projections

### Google Commission
- **15%** of revenue for first $1M/year
- **30%** above $1M/year

### Example (Monthly Plan — 1% conversion)
| Users | Subscribers | Gross/mo | After 15% |
|-------|-------------|----------|-----------|
| 1,000 | 10 | $19.90 | $16.92 |
| 10,000 | 100 | $199.00 | $169.15 |
| 100,000 | 1,000 | $1,990.00 | $1,691.50 |

### Example (Annual Plan — 1% conversion)
| Users | Subscribers | Gross/yr | After 15% |
|-------|-------------|----------|-----------|
| 1,000 | 10 | $199.90 | $169.92 |
| 10,000 | 100 | $1,999.00 | $1,699.15 |
| 100,000 | 1,000 | $19,990.00 | $16,991.50 |

---

## Testing Checklist

### Before Launch:
- [ ] Google Play Developer account created (Individual)
- [ ] App created in Play Console
- [ ] Privacy policy URL added
- [ ] Monthly subscription created (`heatbubble_premium_monthly`) — **$1.99/mo**
- [ ] Annual subscription created (`heatbubble_premium_annual`) — **$19.99/yr**
- [ ] Both subscriptions have **7-day free trial** intro offer (new subscribers only)
- [ ] Both subscriptions set to **Active**
- [ ] Product IDs in code match Play Console exactly
- [ ] License testers added
- [ ] App uploaded to Internal Testing
- [ ] Monthly subscription purchase + trial works
- [ ] Annual subscription purchase + trial works
- [ ] Restore purchases works (e.g. after reinstall)
- [ ] Premium features unlock after purchase/trial
- [ ] Non-premium users see lock/upgrade screen in place of premium features
- [ ] Home screen widget shows lock screen for non-premium users
- [ ] Tax information submitted
- [ ] Bank account added for payments
- [ ] `kDevHomeWidgetBypass = false` set before release

---

## Common Issues

**"Product not found" error:**
- ✅ Check product IDs match exactly (case-sensitive)
- ✅ Ensure subscriptions are **Active** in Play Console
- ✅ Wait 2–4 hours after activating products
- ✅ App must be uploaded to at least Internal Testing track

**"Purchase failed" error:**
- ✅ Test account added to License testing
- ✅ Check internet connection
- ✅ Verify Google Play Services is updated on device

**"Item already owned" error:**
- ✅ Use "Restore purchases" in app
- ✅ Or cancel the subscription in Play Console test orders

**Trial not appearing:**
- ✅ Ensure the introductory offer has eligibility set to "New subscribers only"
- ✅ Use a fresh Google account that has never subscribed before
- ✅ License testers skip the trial (purchase cycles are accelerated instead)

---

## Support Resources

- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Subscriptions Documentation](https://developer.android.com/google/play/billing/subscriptions)
- [Introductory Prices / Free Trials](https://developer.android.com/google/play/billing/subscriptions#introductory)
- [Tax Information](https://support.google.com/googleplay/android-developer/answer/138000)
- [Individual vs Organization Account](https://support.google.com/googleplay/android-developer/answer/6112435)
