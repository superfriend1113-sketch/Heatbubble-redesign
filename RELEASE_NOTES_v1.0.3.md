# HeatBubble v1.0.3 (Build 5) - Release Notes

## 🎯 What's New

### 🚀 Performance & Stability
- **Faster App Launch**: Reduced startup time from 8-10 seconds to 1-2 seconds by optimizing initialization
- **Fixed App Crashes**: Resolved Firebase initialization crashes with lazy loading pattern
- **Improved Ad Reliability**: App open ads now show consistently with better timing and retry logic

### 💰 Monetization Improvements
- **Per-Screen Ads**: Interstitial ads now show once per screen (Home + Settings) for better balance between revenue and user experience
- **Smart Ad Loading**: Ads preload in background with 8-second timeout for slow networks
- **Premium Exemption**: Premium subscribers never see any ads

### 🔐 Authentication & Sync
- **Smoother Signup Flow**: After creating account, users return directly to Settings (no extra navigation)
- **Better Error Handling**: Improved Firebase authentication error messages
- **Lazy Sync**: Firebase services only initialize when needed, preventing crashes

### 💳 Subscription & Payments
- **Restore Purchases**: Production-ready restore functionality for premium subscribers
- **Better Pricing Display**: Improved paywall UI with larger fonts and clearer pricing hierarchy
- **Accurate Prices**: Fixed subscription display to show only actual prices (₹220/month, ₹2,250/year)
- **7-Day Free Trial**: Clear trial badges on all subscription plans

### 🎨 UI/UX Enhancements
- **Updated Upgrade Prompts**: Accurate pricing in all upgrade dialogs
- **Fixed Text Overflow**: Resolved layout issues in upgrade dialogs
- **Better Visual Feedback**: Improved loading states and animations

### 🐛 Bug Fixes
- **Home Widget Package**: Fixed widget service to use correct package name (com.heatbubble.app)
- **Subscription Filtering**: Removed duplicate "Free" entries from subscription list
- **Ad Loading**: Fixed race conditions in ad initialization
- **Navigation**: Fixed signup/login navigation flow

### 📱 Ad Integration
- **Home Screen**: Interstitial ads on temperature unit buttons (°C, °F, K)
- **Settings Screen**: Interstitial ads on all interactive toggles and buttons
- **App Open Ad**: Shows once per session on app launch (free users only)
- **Banner Ads**: Bottom banner on home screen (free users only)

## 🔧 Technical Improvements
- Extended ad loading timeout from 5 to 8 seconds
- Added comprehensive debug logging for ad lifecycle
- Implemented per-screen ad tracking with Set-based storage
- Auto-preload next interstitial ad after showing
- Session-based ad frequency capping

## 📊 Subscription Plans
- **Monthly**: ₹220.00/month with 7-day free trial
- **Annual**: ₹2,250.00/year with 7-day free trial (17% savings)

## 🎁 Premium Features
- ✅ Ad-free experience
- ✅ Cloud sync across devices
- ✅ Unlimited history
- ✅ Custom temperature alerts
- ✅ Home screen widget
- ✅ Priority support

## 🔄 Migration Notes
- No data migration required
- Existing premium subscriptions automatically recognized
- All user data preserved

## 📝 Known Issues
- None reported

## 🙏 Thank You
Thank you for using HeatBubble! We're constantly working to improve your experience.

---

**Version**: 1.0.3 (Build 5)  
**Release Date**: April 2, 2026  
**Minimum Android Version**: Android 5.0 (API 21)  
**Target Android Version**: Android 14 (API 34)
