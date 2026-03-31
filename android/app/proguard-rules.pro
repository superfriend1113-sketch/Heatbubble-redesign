# ── Flutter ─────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# ── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── AdMob / Google Mobile Ads ────────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**

# ── Google Sign-In ───────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── WorkManager ──────────────────────────────────────────────────────────────
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# ── Isar Database ─────────────────────────────────────────────────────────────
-keep class dev.isar.** { *; }
-keep class isar.** { *; }
-keep class **.isar.** { *; }
-keepclassmembers class * {
    @isar.annotations.* *;
}
-dontwarn dev.isar.**

# ── In-App Purchases ─────────────────────────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.** { *; }
-dontwarn com.android.billingclient.**
-dontwarn com.android.vending.**

# ── Home Widget ───────────────────────────────────────────────────────────────
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# ── Kotlin ───────────────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# ── AndroidX / Jetpack ───────────────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**
-keep class com.google.android.material.** { *; }

# ── WebView (needed for AdMob) ───────────────────────────────────────────────
-keep class android.webkit.** { *; }
-keep class org.chromium.** { *; }
-dontwarn org.chromium.**

# ── OkHttp / Networking (transitive dep) ─────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ── Play Core (deferred components - not used) ──────────────────────────────
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── General ──────────────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-dontwarn sun.misc.**
-dontwarn java.lang.invoke.**
-dontwarn **$$Lambda$*
