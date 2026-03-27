package com.example.heatbubble

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews

/**
 * HeatBubble Home Screen Widget
 *
 * Premium gating is enforced HERE on the native side:
 *   - If hw_is_premium == "true"  → show temperature, trend, status
 *   - If hw_is_premium == "false" → show lock screen with upgrade CTA
 *
 * This cannot be bypassed from the OS widget picker since the content
 * is controlled by the data written by Flutter's HomeWidgetService.
 */
class HeatBubbleWidget : AppWidgetProvider() {

    companion object {
        private const val TAG         = "HeatBubbleWidget"
        private const val PREFS_NAME  = "HomeWidgetPreferences"
        private const val KEY_TEMP      = "hw_temperature"
        private const val KEY_TREND     = "hw_trend"
        private const val KEY_ALERT     = "hw_alert"
        private const val KEY_UPDATED   = "hw_updated"
        private const val KEY_STATUS    = "hw_status"
        private const val KEY_IS_PREMIUM = "hw_is_premium"
        private const val KEY_TIP         = "hw_tip"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val isPremium = prefs.getString(KEY_IS_PREMIUM, "false") == "true"
        val temp      = prefs.getString(KEY_TEMP,    null) ?: "--"
        val trend     = prefs.getString(KEY_TREND,   null) ?: "Stable"
        val alert     = prefs.getString(KEY_ALERT,   "false") == "true"
        val updated   = prefs.getString(KEY_UPDATED, null) ?: ""
        val status    = prefs.getString(KEY_STATUS,  null) ?: "Normal"
        val tip       = prefs.getString(KEY_TIP,     null) ?: ""

        val trendDisplay = when (trend) {
            "Rising"  -> "^ Rising"
            "Falling" -> "v Falling"
            else      -> "- Stable"
        }

        Log.d(TAG, "onUpdate: premium=$isPremium temp=$temp trend=$trendDisplay status=$status")

        for (id in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.heatbubble_widget)

                if (isPremium) {
                    // ── UNLOCKED: show temperature data ──
                    showPremiumContent(views, temp, trendDisplay, status, updated, alert, tip)
                } else {
                    // ── LOCKED: show upgrade prompt ──
                    showLockScreen(views)
                }

                // Tap anything → open the app
                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else PendingIntent.FLAG_UPDATE_CURRENT
                    val pi = PendingIntent.getActivity(context, id, launchIntent, flags)
                    // Apply to both locked and unlocked tap targets
                    views.setOnClickPendingIntent(R.id.widget_lock_cta, pi)
                    views.setOnClickPendingIntent(R.id.widget_temperature, pi)
                }

                appWidgetManager.updateAppWidget(id, views)
                Log.d(TAG, "Widget $id rendered OK (premium=$isPremium)")
            } catch (e: Exception) {
                Log.e(TAG, "Widget $id FAILED: ${e.message}", e)
            }
        }
    }

    // ── Show full temperature content (premium users) ──────────────────────
    private fun showPremiumContent(
        views: RemoteViews,
        temp: String,
        trend: String,
        status: String,
        updated: String,
        alert: Boolean,
        tip: String
    ) {
        // Hide lock views
        views.setViewVisibility(R.id.widget_lock_icon,    View.GONE)
        views.setViewVisibility(R.id.widget_lock_title,   View.GONE)
        views.setViewVisibility(R.id.widget_lock_message, View.GONE)
        views.setViewVisibility(R.id.widget_lock_cta,     View.GONE)

        // Show content views
        views.setViewVisibility(R.id.widget_app_name,   View.VISIBLE)
        views.setViewVisibility(R.id.widget_temperature, View.VISIBLE)
        views.setViewVisibility(R.id.widget_trend,       View.VISIBLE)
        views.setViewVisibility(R.id.widget_status,      View.VISIBLE)
        views.setViewVisibility(R.id.widget_updated,     View.VISIBLE)
        views.setViewVisibility(R.id.widget_alert,
            if (alert) View.VISIBLE else View.GONE)
        // Show tip if available
        val showTip = tip.isNotEmpty()
        views.setViewVisibility(R.id.widget_tip, if (showTip) View.VISIBLE else View.GONE)
        if (showTip) views.setTextViewText(R.id.widget_tip, tip)

        // Set text values
        views.setTextViewText(R.id.widget_temperature, temp)
        views.setTextViewText(R.id.widget_trend,       trend)
        views.setTextViewText(R.id.widget_status,      status)
        views.setTextViewText(R.id.widget_updated,     updated)
    }

    // ── Show lock / upgrade screen (non-premium users) ────────────────────
    private fun showLockScreen(views: RemoteViews) {
        // Show lock views
        views.setViewVisibility(R.id.widget_lock_icon,    View.VISIBLE)
        views.setViewVisibility(R.id.widget_lock_title,   View.VISIBLE)
        views.setViewVisibility(R.id.widget_lock_message, View.VISIBLE)
        views.setViewVisibility(R.id.widget_lock_cta,     View.VISIBLE)

        // Hide all content views including tip
        views.setViewVisibility(R.id.widget_app_name,   View.GONE)
        views.setViewVisibility(R.id.widget_temperature, View.GONE)
        views.setViewVisibility(R.id.widget_trend,       View.GONE)
        views.setViewVisibility(R.id.widget_status,      View.GONE)
        views.setViewVisibility(R.id.widget_updated,     View.GONE)
        views.setViewVisibility(R.id.widget_alert,       View.GONE)
        views.setViewVisibility(R.id.widget_tip,         View.GONE)
    }
}
