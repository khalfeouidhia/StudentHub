package com.example.studenthold_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class BalanceExpensesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_balance_expenses)

            val balance = widgetData.getString("budget_balance", "0.000 DT") ?: "0.000 DT"
            val spent = widgetData.getString("budget_spent", "0.000 DT") ?: "0.000 DT"
            val progressText = widgetData.getString("budget_progress_text", "0% / 0 DT Cap") ?: "0% / 0 DT Cap"
            val progressPercent = widgetData.getInt("budget_progress_percent", 0)
            val dailySafe = widgetData.getString("budget_daily_safe", "0.000 DT/day") ?: "0.000 DT/day"

            views.setTextViewText(R.id.widget_budget_balance, balance)
            views.setTextViewText(R.id.widget_budget_spent, spent)
            views.setTextViewText(R.id.widget_budget_cap_info, progressText)
            views.setTextViewText(R.id.widget_budget_daily_safe, dailySafe)
            views.setProgressBar(R.id.widget_budget_progress_bar, 100, progressPercent, false)

            // Deep link intent to open StudentHub Home / Add Expense
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("studenthub://expense")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_budget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
