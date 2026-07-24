package com.example.seance

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the current week's séance reading. The data is
 * written from Dart via the `home_widget` plugin (see WidgetService) into the
 * shared [SharedPreferences] this provider reads on each update.
 */
class ReadingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.reading_widget).apply {
                val title = widgetData.getString("reading_title", null)
                    ?: "This week's reading"
                val excerpt = widgetData.getString("reading_excerpt", null)
                    ?: "Open séance to begin your weekly reading."
                val meta = widgetData.getString("reading_meta", null) ?: "SÉANCE"

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_excerpt, excerpt)
                setTextViewText(R.id.widget_meta, meta)

                // Tapping anywhere on the widget opens the app.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
