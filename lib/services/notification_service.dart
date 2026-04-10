import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Motivasyon bildirimleri
  static const List<String> _motivationalMessages = [
    "Did you practice English today? Even 5 minutes makes a difference.",
    "Small steps every day bring big success. Keep practicing.",
    "Learning a language requires consistency. Move forward with your goals today.",
    "It's a great day to improve your speaking skills. Let's start.",
    "Are you ready to learn new words today?",
    "Improve your fluency by practicing aloud.",
    "Regular practice leads to fast progress. Pick up where you left off.",
    "Every conversation is a step forward. Practice today, too.",
    "Keep your streak! Complete your practice today.",
    "Your confidence in speaking English is growing every day.",
  ];

  // Premium tanıtım mesajları
  static const List<String> _premiumMessages = [
    "Get unlimited practice with a Premium membership.",
    "Unlock all features with a Premium account.",
    "Reach your goals faster with Premium.",
    "Discover Premium benefits and experience unlimited conversations.",
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Timezone'u başlat
    tz_data.initializeTimeZones();
    // Yerel timezone'u ayarla (Türkiye için Europe/Istanbul)
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android ayarları
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS ayarları
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Bildirime tıklandığında yapılacak işlemler
    // Uygulamayı açar
  }

  /// Bildirim geçmişine kaydet
  Future<void> _saveNotificationToHistory({
    required String type,
    required String title,
    required String message,
    DateTime? timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getStringList('notification_history') ?? [];

    final dateStr = (timestamp ?? DateTime.now()).toIso8601String();
    final entry = '$dateStr|$type|$title|$message';

    // En başa ekle (yeni bildirimler üstte)
    notifications.insert(0, entry);

    // Maksimum 50 bildirim tut
    if (notifications.length > 50) {
      notifications.removeRange(50, notifications.length);
    }

    await prefs.setStringList('notification_history', notifications);
  }

  /// Anlık bildirim gönder ve geçmişe kaydet
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    required String type,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          type == 'premium' ? 'premium_reminder' : 'daily_motivation',
          type == 'premium' ? 'Premium Reminder' : 'Daily Motivation',
          channelDescription:
              type == 'premium'
                  ? 'Weekly premium reminder notifications'
                  : 'Daily motivation notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Geçmişe kaydet
    await _saveNotificationToHistory(type: type, title: title, message: body);
  }

  /// Bildirim izni iste
  Future<bool> requestPermission() async {
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// Günlük motivasyon bildirimini planla (her gün saat 19:00)
  Future<void> scheduleDailyMotivation() async {
    await _notifications.zonedSchedule(
      1, // Bildirim ID
      'English Practice Time',
      _getRandomMotivationalMessage(),
      _nextInstanceOfTime(19, 0), // Akşam 7
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_motivation',
          'Daily Motivation',
          channelDescription: 'Daily motivation notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün tekrarla
    );
  }

  /// Haftalık premium bildirimi planla (her Pazartesi saat 12:00)
  Future<void> scheduleWeeklyPremiumReminder() async {
    await _notifications.zonedSchedule(
      2, // Bildirim ID
      'Premium Opportunity',
      _getRandomPremiumMessage(),
      _nextInstanceOfDayAndTime(DateTime.monday, 12, 0),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'premium_reminder',
          'Premium Reminder',
          channelDescription: 'Weekly premium reminder notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Premium hatırlatıcıyı iptal et (premium olunca)
  Future<void> cancelPremiumReminder() async {
    await _notifications.cancel(2);
  }

  /// Tüm zamanlanmış bildirimleri iptal et
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Yardımcı metodlar
  String _getRandomMotivationalMessage() {
    final random = Random();
    return _motivationalMessages[random.nextInt(_motivationalMessages.length)];
  }

  String _getRandomPremiumMessage() {
    final random = Random();
    return _premiumMessages[random.nextInt(_premiumMessages.length)];
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    var scheduledDate = _nextInstanceOfTime(hour, minute);

    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Bildirim geçmişini getir
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getStringList('notification_history') ?? [];

    return notifications.map((n) {
      final parts = n.split('|');
      if (parts.length >= 4) {
        return {
          'timestamp': DateTime.tryParse(parts[0]) ?? DateTime.now(),
          'type': parts[1],
          'title': parts[2],
          'message': parts[3],
        };
      }
      return {
        'timestamp': DateTime.now(),
        'type': 'unknown',
        'title': 'Notification',
        'message': n,
      };
    }).toList();
  }

  /// Bildirim geçmişini temizle
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
  }

  /// Bildirimleri başlat (premium durumuna göre)
  Future<void> setupNotifications({required bool isPremium}) async {
    await initialize();
    await requestPermission();

    // Geçmiş bildirimleri kontrol et ve eksik olanları ekle
    await _backfillMissedNotifications(isPremium: isPremium);

    // Günlük motivasyon bildirimi
    await scheduleDailyMotivation();

    // Premium değilse haftalık premium hatırlatıcı
    if (!isPremium) {
      await scheduleWeeklyPremiumReminder();
    } else {
      await cancelPremiumReminder();
    }
  }

  /// Uygulama açıldığında, son bildirimden bu yana kaçırılmış bildirimleri geçmişe ekle
  Future<void> _backfillMissedNotifications({required bool isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastDailyCheck = prefs.getString('last_daily_notification_date');
    final lastWeeklyCheck = prefs.getString('last_weekly_notification_date');
    final now = DateTime.now();

    // === Günlük motivasyon bildirimleri ===
    DateTime startDate;
    if (lastDailyCheck != null) {
      startDate =
          DateTime.tryParse(lastDailyCheck) ??
          now.subtract(const Duration(days: 1));
      // Bir sonraki günden başla
      startDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(const Duration(days: 1));
    } else {
      // İlk kez - sadece bugün için ekle
      startDate = DateTime(now.year, now.month, now.day);
    }

    // Bugünün saat 19:00'u geçtiyse bugünü de dahil et
    final todayNotificationTime = DateTime(now.year, now.month, now.day, 19, 0);
    final endDate =
        now.isAfter(todayNotificationTime)
            ? DateTime(now.year, now.month, now.day)
            : DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 1));

    // Eksik günleri doldur (maksimum 7 gün geriye git)
    var currentDate = startDate;
    int addedCount = 0;
    while (!currentDate.isAfter(endDate) && addedCount < 7) {
      final notificationTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        19,
        0,
      );
      await _saveNotificationToHistory(
        type: 'motivation',
        title: 'English Practice Time',
        message: _getRandomMotivationalMessage(),
        timestamp: notificationTime,
      );
      currentDate = currentDate.add(const Duration(days: 1));
      addedCount++;
    }

    // Son günlük bildirim tarihini güncelle
    if (now.isAfter(todayNotificationTime)) {
      await prefs.setString(
        'last_daily_notification_date',
        DateTime(now.year, now.month, now.day).toIso8601String(),
      );
    } else if (endDate.isAfter(startDate.subtract(const Duration(days: 1)))) {
      await prefs.setString(
        'last_daily_notification_date',
        endDate.toIso8601String(),
      );
    }

    // === Haftalık premium bildirimi ===
    if (!isPremium) {
      DateTime lastWeekly;
      if (lastWeeklyCheck != null) {
        lastWeekly =
            DateTime.tryParse(lastWeeklyCheck) ??
            now.subtract(const Duration(days: 8));
      } else {
        lastWeekly = now.subtract(const Duration(days: 8));
      }

      // Son bildirimden bu yana 7 gün geçtiyse ekle
      if (now.difference(lastWeekly).inDays >= 7) {
        // En son Pazartesi'yi bul
        var lastMonday = now;
        while (lastMonday.weekday != DateTime.monday) {
          lastMonday = lastMonday.subtract(const Duration(days: 1));
        }
        final mondayNoon = DateTime(
          lastMonday.year,
          lastMonday.month,
          lastMonday.day,
          12,
          0,
        );

        if (mondayNoon.isBefore(now) && mondayNoon.isAfter(lastWeekly)) {
          await _saveNotificationToHistory(
            type: 'premium',
            title: 'Premium Opportunity',
            message: _getRandomPremiumMessage(),
            timestamp: mondayNoon,
          );
          await prefs.setString(
            'last_weekly_notification_date',
            mondayNoon.toIso8601String(),
          );
        }
      }
    }
  }
}
