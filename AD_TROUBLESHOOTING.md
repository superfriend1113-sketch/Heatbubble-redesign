# Ad Troubleshooting Guide for HeatBubble

## Current Ad Configuration

### Ad Unit IDs (Google Test IDs)
- **Banner**: `ca-app-pub-3940256099942544/6300978111`
- **Interstitial**: `ca-app-pub-3940256099942544/1033173712`
- **App Open**: `ca-app-pub-3940256099942544/9257395921`
- **App ID (Manifest)**: `ca-app-pub-3940256099942544~3347511713`

These are official Google test IDs that should work on ALL devices.

## Why Ads Might Not Show

### 1. Premium Status Check
**Most Common Issue**: User might be marked as premium locally.

**How to Check**:
1. Open the app
2. Go to Settings screen
3. Look at "Subscription" section
4. If it says "Premium Active" → Ads won't show!

**How to Fix**:
- Uninstall and reinstall the app (clears local data)
- OR manually clear app data in Android Settings

### 2. Session Tracking
Ads are designed to show ONCE per session:
- **App Open Ad**: Shows once when app launches (first time only)
- **Interstitial Ads**: Shows once per screen (home/settings) per session
- **Banner Ads**: Should always show on home screen

**How to Test**:
- Close app completely (swipe away from recent apps)
- Reopen app → App open ad should show
- Navigate to home → Banner should show
- Tap unit buttons (°C, °F, K) → Interstitial should show (first time only)

### 3. Ad Loading Time
- **App Open Ad**: Has 8-second timeout
- **Banner Ad**: Loads asynchronously
- **Interstitial Ad**: Preloaded in background

**Slow Network**: If network is slow, ads might not load in time.

### 4. Android System WebView
AdMob requires Android System WebView to be up-to-date.

**How to Check**:
1. Open Google Play Store
2. Search "Android System WebView"
3. If "Update" button shows → Update it!
4. Restart device after update

### 5. Debug Logs
The app prints detailed ad logs. To see them:

**Using Android Studio**:
1. Connect device via USB
2. Open Logcat
3. Filter by "AdsService"
4. Look for these messages:
   - `✅ Banner ad LOADED successfully` → Ad is working
   - `❌ Banner ad FAILED to load` → Check error code
   - `⚠️ User is premium, skipping` → Premium status issue

**Error Codes**:
- **Code 0**: Internal error (often WebView issue)
- **Code 1**: Invalid request (configuration issue)
- **Code 2**: Network error (internet connection)
- **Code 3**: No fill (no ad inventory available)

## Testing Checklist

### Step 1: Verify Not Premium
- [ ] Open Settings
- [ ] Check subscription shows "Free Tier"
- [ ] If shows "Premium Active" → Uninstall/reinstall app

### Step 2: Test App Open Ad
- [ ] Close app completely
- [ ] Reopen app
- [ ] Wait 2-10 seconds
- [ ] App open ad should show full screen
- [ ] If not, check logs for error

### Step 3: Test Banner Ad
- [ ] Navigate to Home screen
- [ ] Wait 3-5 seconds
- [ ] Banner should appear at bottom
- [ ] If not, check logs for error

### Step 4: Test Interstitial Ad
- [ ] On Home screen, tap °C button
- [ ] Interstitial should show full screen
- [ ] Close ad
- [ ] Tap °F button → No ad (already shown this session)
- [ ] Close and reopen app
- [ ] Tap K button → Ad should show again

### Step 5: Check WebView
- [ ] Open Play Store
- [ ] Search "Android System WebView"
- [ ] Update if available
- [ ] Restart device

## Common Solutions

### Solution 1: Clear Premium Status
```bash
# Uninstall app
adb uninstall com.heatbubble.app

# Reinstall
flutter run
```

### Solution 2: Force Ad Reload
In `lib/services/ads_service.dart`, add this method:
```dart
void forceReload() {
  resetSession();
  disposeBannerAd();
  loadBannerAd();
  loadInterstitialAd();
  loadAppOpenAd();
}
```

### Solution 3: Increase Timeouts
In `lib/services/ads_service.dart`, change:
```dart
// From 8 seconds to 15 seconds
while (_appOpenAd == null && attempts < 30) {  // was 16
  await Future.delayed(const Duration(milliseconds: 500));
  attempts++;
}
```

## Production Ad IDs

When ready for production, replace test IDs with real ones:

**In `lib/services/ads_service.dart`**:
```dart
// Production IDs (get from AdMob console)
static const String _bannerAdUnitId = 'ca-app-pub-3676471973768636/XXXXXXXXXX';
static const String _interstitialAdUnitId = 'ca-app-pub-3676471973768636/XXXXXXXXXX';
static const String _appOpenAdUnitId = 'ca-app-pub-3676471973768636/XXXXXXXXXX';
```

**In `android/app/src/main/AndroidManifest.xml`**:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3676471973768636~4261706101"/>
```

## Need More Help?

Check the debug logs in Android Studio Logcat with filter "AdsService" to see exactly what's happening.
