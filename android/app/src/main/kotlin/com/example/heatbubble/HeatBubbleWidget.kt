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

class HeatBubbleWidget : AppWidgetProvider() {

    companion object {
        private const val TAG        = "HeatBubbleWidget"
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_TEMP    = "hw_temperature"
        private const val KEY_TREND   = "hw_trend"
        private const val KEY_ALERT   = "hw_alert"
        private const val KEY_UPDATED = "hw_updated"
        private const val KEY_STATUS  = "hw_status"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val temp    = prefs.getString(KEY_TEMP,    null) ?: "--"
        val trend   = prefs.getString(KEY_TREND,   null) ?: "Stable"
        val alert   = prefs.getString(KEY_ALERT,   "false") == "true"
        val updated = prefs.getString(KEY_UPDATED, null) ?: ""
        val status  = prefs.getString(KEY_STATUS,  null) ?: "Normal"

        val trendDisplay = when (trend) {
            "Rising"  -> "^ Rising"
            "Falling" -> "v Falling"
            else      -> "- Stable"
        }

        Log.d(TAG, "onUpdate: temp=$temp trend=$trendDisplay status=$status alert=$alert")

        for (id in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.heatbubble_widget)

                // Only setTextViewText — no setInt, no setTextColor, no setBackgroundColor
                views.setTextViewText(R.id.widget_temperature, temp)
                views.setTextViewText(R.id.widget_trend, trendDisplay)
                views.setTextViewText(R.id.widget_status, status)
                views.setTextViewText(R.id.widget_updated, updated)
                views.setViewVisibility(
                    R.id.widget_alert,
                    if (alert) View.VISIBLE else View.GONE
                )

                // Tap → open app
                val intent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                if (intent != null) {
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else PendingIntent.FLAG_UPDATE_CURRENT
                    val pi = PendingIntent.getActivity(context, id, intent, flags)
                    views.setOnClickPendingIntent(R.id.widget_temperature, pi)
                }

                appWidgetManager.updateAppWidget(id, views)
                Log.d(TAG, "Widget $id OK: $temp $trendDisplay")
            } catch (e: Exception) {
                Log.e(TAG, "Widget $id FAILED: ${e.message}", e)
            }
        }
    }
}
