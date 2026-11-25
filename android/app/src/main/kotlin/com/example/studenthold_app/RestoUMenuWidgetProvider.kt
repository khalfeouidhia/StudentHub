package com.example.studenthold_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class RestoUMenuWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_resto_u_menu)

            val title = widgetData.getString("resto_title", "Menu Resto U") ?: "Menu Resto U"
            val dayLabel = widgetData.getString("resto_day_label", "Aujourd'hui") ?: "Aujourd'hui"
            val isReserved = widgetData.getBoolean("resto_is_reserved", false)
            val statusText = widgetData.getString("resto_badge_text", if (isReserved) "Réservé" else "Non réservé") ?: "Non réservé"

            val entree = widgetData.getString("resto_entree", "Entrée du jour") ?: "Entrée du jour"
            val mainCourse = widgetData.getString("resto_main", "Plat principal") ?: "Plat principal"
            val dessert = widgetData.getString("resto_dessert", "Dessert / Fruit") ?: "Dessert / Fruit"

            views.setTextViewText(R.id.widget_resto_day, dayLabel)
            views.setTextViewText(R.id.widget_resto_title, title)
            views.setTextViewText(R.id.widget_resto_status, statusText)

            if (isReserved) {
                views.setInt(R.id.widget_resto_status, "setBackgroundResource", R.drawable.widget_badge_reserved)
            } else {
                views.setInt(R.id.widget_resto_status, "setBackgroundResource", R.drawable.widget_badge_not_reserved)
            }

            views.setTextViewText(R.id.widget_dish_main, mainCourse)
            views.setTextViewText(R.id.widget_dish_entree, entree)
            views.setTextViewText(R.id.widget_dish_dessert, dessert)

            // Deep link intent to open StudentHub Resto U tab
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("studenthub://resto")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_resto_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
