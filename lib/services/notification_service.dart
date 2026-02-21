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
    "🎯 Bugün İngilizce pratiği yaptın mı? 5 dakika bile fark yaratır!",
    "🌟 Her gün küçük adımlar, büyük başarılar getirir. Hadi pratik yapalım!",
    "💪 Dil öğrenmek maraton, sprint değil. Bugün de devam edelim!",
    "🚀 Konuşma becerilerini geliştirmek için harika bir gün. Başlayalım!",
    "📚 Bugün yeni kelimeler öğrenmeye hazır mısın?",
    "🎤 Sesli pratik yaparak akıcılığını artır. Hemen başla!",
    "⭐ Düzenli pratik = Hızlı ilerleme. Bugün senin günün!",
    "🌈 Her konuşma bir adım ileri. Bugün de adım at!",
    "🔥 Streak'ini koru! Bugün de pratik yap.",
    "💫 İngilizce konuşma özgüvenin her gün artıyor. Devam et!",
  ];

  // Premium tanıtım mesajları
  static const List<String> _premiumMessages = [
    "👑 Premium ile sınırsız pratik! Şimdi dene.",
    "🎁 Premium üyelikle tüm özelliklere eriş!",
    "⚡ Premium ile daha hızlı öğren, daha çok pratik yap!",
    "💎 Premium avantajlarını keşfet. Sınırsız konuşma seni bekliyor!",
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getStringList('notification_history') ?? [];

    final now = DateTime.now().toIso8601String();
    final entry = '$now|$type|$title|$message';

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
          type == 'premium' ? 'Premium Hatırlatıcı' : 'Günlük Motivasyon',
          channelDescription:
              type == 'premium'
                  ? 'Haftalık premium hatırlatma bildirimleri'
                  : 'Günlük motivasyon bildirimleri',
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
      'İngilizce Pratik Zamanı! 🎯',
      _getRandomMotivationalMessage(),
      _nextInstanceOfTime(19, 0), // Akşam 7
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_motivation',
          'Günlük Motivasyon',
          channelDescription: 'Günlük motivasyon bildirimleri',
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
      'Premium Fırsatı! 👑',
      _getRandomPremiumMessage(),
      _nextInstanceOfDayAndTime(DateTime.monday, 12, 0),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'premium_reminder',
          'Premium Hatırlatıcı',
          channelDescription: 'Haftalık premium hatırlatma bildirimleri',
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
        'title': 'Bildirim',
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

    // Günlük motivasyon bildirimi
    await scheduleDailyMotivation();

    // Premium değilse haftalık premium hatırlatıcı
    if (!isPremium) {
      await scheduleWeeklyPremiumReminder();
    } else {
      await cancelPremiumReminder();
    }
  }
}
