import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../controllers/campus_resto_controller.dart';
import '../models/campus_meal_item.dart';

/// Manages local notifications for university restaurant meal reservation reminders.
///
/// Features:
/// - Daily 8:00 AM reminder in `Africa/Tunis` local time.
/// - Smart suppression: cancels/skips notification if tomorrow's meals are already
///   reserved or if tomorrow has no scheduled service (e.g. Sunday or holidays).
/// - Deep linking: payload 'resto_u' opens the university restaurant screen directly.
class RestoNotificationService {
  static const String channelId = 'resto_u_reminders';
  static const String channelName = 'Resto U Reminders';
  static const String channelDescription =
      'Daily 8:00 AM reservation reminders before noon deadline';
  static const int reminderNotificationId = 800;

  static const String notificationTitle = "🍽️ Reserve Tomorrow's Resto U Meal!";
  static const String notificationBody =
      "Reservations close at 12:00 PM today. Tap to book tomorrow's Déjeuner & Dîner before noon.";
  static const String notificationPayload = 'resto_u';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  /// Global callback for routing when the notification is tapped by the user.
  static void Function(String? payload)? onNotificationTapped;

  RestoNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool get isInitialized => _isInitialized;

  /// Initializes the notification plugin and timezone database.
  Future<void> init({void Function(String? payload)? onTapped}) async {
    if (onTapped != null) {
      onNotificationTapped = onTapped;
    }

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Tunis'));
    } catch (e) {
      debugPrint('RestoNotificationService: Timezone init fallback - $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (onNotificationTapped != null) {
          onNotificationTapped!(payload);
        }
      },
    );

    _isInitialized = true;
  }

  /// Prompts the user for runtime notification permissions on Android 13+ (API 33+) and iOS.
  Future<bool?> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission();
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return true;
  }

  /// Evaluates whether an 8:00 AM reminder should be scheduled for tomorrow's meals.
  ///
  /// Suppression Rules:
  /// 1. Tomorrow has NO meals scheduled in the weekly calendar (e.g. Sunday or holiday) -> Suppress (`false`).
  /// 2. ALL available meals for tomorrow are already reserved by the student -> Suppress (`false`).
  /// 3. Tomorrow has scheduled meals AND at least one meal is still [MealStatus.notReserved] -> Notify (`true`).
  bool shouldNotifyForTomorrow({
    required CampusRestoController controller,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final tomorrow = DateTime(current.year, current.month, current.day + 1);
    final tomorrowDateKey =
        '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    final mealsForTomorrow = controller.weeklyMeals
        .where((m) => m.dateKey == tomorrowDateKey)
        .toList();

    if (mealsForTomorrow.isEmpty) {
      return false;
    }

    final hasUnreserved =
        mealsForTomorrow.any((m) => m.status == MealStatus.notReserved);
    return hasUnreserved;
  }

  /// Synchronizes the 8:00 AM reservation reminder based on current reservation status.
  ///
  /// Cancels existing reminder if tomorrow is already reserved or closed.
  /// Schedules the 8:00 AM reminder if meals are available and unreserved.
  Future<bool> syncReservationReminder({
    required CampusRestoController controller,
    DateTime? now,
  }) async {
    try {
      final eligible = shouldNotifyForTomorrow(controller: controller, now: now);
      if (!eligible) {
        await cancelReminder();
        return false;
      }

      await schedule8AmReminder(now: now);
      return true;
    } catch (e) {
      debugPrint('RestoNotificationService: syncReservationReminder error - $e');
      return false;
    }
  }

  /// Schedules the recurring daily 8:00 AM reminder in `Africa/Tunis` local time.
  Future<void> schedule8AmReminder({DateTime? now}) async {
    tz.Location location;
    try {
      location = tz.getLocation('Africa/Tunis');
    } catch (_) {
      location = tz.local;
    }

    final current = now ?? DateTime.now();
    final nowTz = tz.TZDateTime.from(current, location);
    var scheduledTz = tz.TZDateTime(
      location,
      nowTz.year,
      nowTz.month,
      nowTz.day,
      8,
      0,
    );

    if (nowTz.isAfter(scheduledTz)) {
      scheduledTz = scheduledTz.add(const Duration(days: 1));
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: reminderNotificationId,
        title: notificationTitle,
        body: notificationBody,
        scheduledDate: scheduledTz,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: notificationPayload,
      );
    } catch (e) {
      debugPrint('RestoNotificationService: exact alarm failed, falling back to inexact: $e');
      try {
        await _plugin.zonedSchedule(
          id: reminderNotificationId,
          title: notificationTitle,
          body: notificationBody,
          scheduledDate: scheduledTz,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: notificationPayload,
        );
      } catch (inner) {
        debugPrint('RestoNotificationService: inexact alarm failed: $inner');
      }
    }
  }

  /// Cancels the scheduled 8:00 AM reservation reminder.
  Future<void> cancelReminder() async {
    try {
      await _plugin.cancel(id: reminderNotificationId);
    } catch (e) {
      debugPrint('RestoNotificationService: cancelReminder failed: $e');
    }
  }

  /// Directly displays an immediate reminder notification (useful for testing and immediate deadline warnings).
  Future<void> showImmediateReminder() async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: reminderNotificationId,
      title: notificationTitle,
      body: notificationBody,
      notificationDetails: notificationDetails,
      payload: notificationPayload,
    );
  }
}
