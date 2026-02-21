import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserProgress? _progress;
  User? _authUser;
  String _userId = 'user_123'; // Fallback / Dev ID
  bool _isLoading = false;

  // Leaderboard
  List<LeaderboardEntry> _leaderboard = [];
  int? _currentRank;
  bool _isLeaderboardLoading = false;

  // Kullanım takibi
  int _todayUsedMinutes = 0;
  int _weeklyUsedMinutes = 0;

  // Günlük takip (her gün sıfırlanır)
  int _todayConversations = 0;
  List<String> _todayCompletedScenarios = [];
  int _todayScenariosStarted = 0; // Günlük başlatılan senaryo sayısı

  // Günlük senaryo limiti (ücretsiz kullanıcılar için)
  static const int dailyScenarioLimit = 2;

  UserProgress? get progress => _progress;
  String get userId => _authUser?.uid ?? _userId;
  bool get isLoading => _isLoading;
  bool get isLeaderboardLoading => _isLeaderboardLoading;
  int get todayUsedMinutes => _todayUsedMinutes;
  int get weeklyUsedMinutes => _weeklyUsedMinutes;
  int get todayConversations => _todayConversations;
  List<String> get todayCompletedScenarios => _todayCompletedScenarios;
  int get todayScenariosStarted => _todayScenariosStarted;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  int? get currentRank => _currentRank;

  int get remainingDailyScenarios =>
      (dailyScenarioLimit - _todayScenariosStarted).clamp(
        0,
        dailyScenarioLimit,
      );

  void updateAuthUser(User? user) {
    _authUser = user;
    if (user != null) {
      _userId = user.uid;
      loadProgress(); // Reload progress for new user
    }
    notifyListeners();
  }

  /// Premium olmayan kullanıcılar için günlük senaryo limiti kontrolü
  bool canStartScenario(bool isPremium) {
    if (isPremium) return true;
    return _todayScenariosStarted < dailyScenarioLimit;
  }

  Future<void> loadProgress() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Önce lokal verileri yükle (hızlı gösterim için)
      await _loadPersistentStats();
      await _loadUsageStats();

      // 2. Backend'den güncel verileri çek ve senkronize et
      try {
        final backendProgress = await _apiService.getUserProgress(userId);

        // Backend verisi daha yeniyse merge et
        if (backendProgress.totalConversations >
            (_progress?.totalConversations ?? 0)) {
          _progress = backendProgress;
          // Local'i güncelle
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            'total_conversations',
            _progress!.totalConversations,
          );
          await prefs.setInt('total_time_minutes', _progress!.totalTimeMinutes);
          await prefs.setStringList(
            'completed_scenarios',
            _progress!.completedScenarios,
          );
          await prefs.setString('current_level', _progress!.currentLevel);
        }

        // Rank bilgisini al
        _currentRank = backendProgress.rank;
      } catch (e) {
        debugPrint('Backend sync error: $e');
        // Backend hatası olsa bile local veriyle devam et
      }

      _updateLevel();
    } catch (e) {
      // Hata durumunda varsayılan değerler
      if (_progress == null) {
        _progress = UserProgress(
          userId: userId,
          totalConversations: 0,
          totalTimeMinutes: 0,
          usedTimeMinutes: 0,
          currentLevel: 'beginner',
          completedScenarios: [],
        );
      }
      await _loadUsageStats();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Leaderboard verilerini yükle
  Future<void> loadLeaderboard() async {
    _isLeaderboardLoading = true;
    notifyListeners();

    try {
      _leaderboard = await _apiService.getLeaderboard();

      // Kullanıcının güncel sırasını bul
      final myEntry = _leaderboard.where((e) => e.userId == userId).firstOrNull;
      if (myEntry != null) {
        _currentRank = myEntry.rank;
      }
    } catch (e) {
      debugPrint('Leaderboard loading error: $e');
    } finally {
      _isLeaderboardLoading = false;
      notifyListeners();
    }
  }

  /// Kalıcı istatistikleri SharedPreferences'tan yükle
  Future<void> _loadPersistentStats() async {
    final prefs = await SharedPreferences.getInstance();

    final totalConversations = prefs.getInt('total_conversations') ?? 0;
    final totalTimeMinutes = prefs.getInt('total_time_minutes') ?? 0;
    final completedScenarios = prefs.getStringList('completed_scenarios') ?? [];
    final currentLevel = prefs.getString('current_level') ?? 'beginner';

    _progress = UserProgress(
      userId: userId,
      totalConversations: totalConversations,
      totalTimeMinutes: totalTimeMinutes,
      usedTimeMinutes: totalTimeMinutes,
      currentLevel: currentLevel,
      completedScenarios: completedScenarios,
    );
  }

  Future<void> _loadUsageStats() async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    _todayUsedMinutes = prefs.getInt('usage_$todayKey') ?? 0;
    _todayConversations = prefs.getInt('conversations_$todayKey') ?? 0;
    _todayCompletedScenarios = prefs.getStringList('scenarios_$todayKey') ?? [];
    _todayScenariosStarted = prefs.getInt('scenarios_started_$todayKey') ?? 0;

    _weeklyUsedMinutes = 0;
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final key = '${date.year}-${date.month}-${date.day}';
      _weeklyUsedMinutes += prefs.getInt('usage_$key') ?? 0;
    }
  }

  Future<void> incrementDailyScenarioCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    _todayScenariosStarted += 1;
    await prefs.setInt('scenarios_started_$todayKey', _todayScenariosStarted);
    notifyListeners();
  }

  Future<void> addUsageTime(int minutes) async {
    if (_progress == null) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    _todayUsedMinutes += minutes;
    await prefs.setInt('usage_$todayKey', _todayUsedMinutes);

    _progress = _progress!.copyWith(
      usedTimeMinutes: _progress!.usedTimeMinutes + minutes,
      totalTimeMinutes: _progress!.totalTimeMinutes + minutes,
    );

    await prefs.setInt('total_time_minutes', _progress!.totalTimeMinutes);
    await _loadUsageStats();

    notifyListeners();
  }

  Future<void> updateProgressAfterConversation({
    required int addedMinutes,
    required String completedScenario,
  }) async {
    if (_progress == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Kullanım süresini ekle
    await addUsageTime(addedMinutes);

    // Günlük konuşma ve senaryo sayısını güncelle
    await _updateDailyStats(completedScenario);

    final newCompletedScenarios = [
      ..._progress!.completedScenarios,
      if (!_progress!.completedScenarios.contains(completedScenario))
        completedScenario,
    ];

    _progress = _progress!.copyWith(
      totalConversations: _progress!.totalConversations + 1,
      completedScenarios: newCompletedScenarios,
    );

    // Local Save
    await prefs.setInt('total_conversations', _progress!.totalConversations);
    await prefs.setInt('total_time_minutes', _progress!.totalTimeMinutes);
    await prefs.setStringList('completed_scenarios', newCompletedScenarios);

    _updateLevel();
    await prefs.setString('current_level', _progress!.currentLevel);

    // Backend Sync
    try {
      // Her dakika 10 XP olsun (basit bir mantık)
      final xpEarned = addedMinutes * 10;

      await _apiService.updateUserProgress(
        userId: userId,
        totalMinutes: _progress!.totalTimeMinutes,
        totalConversations: _progress!.totalConversations,
        completedScenario: completedScenario,
        addedXp: xpEarned,
        displayName: _authUser?.displayName,
      );

      // Güncel rank'i almak için leaderboard'u yenileyebiliriz
      // loadLeaderboard(); // Belki çok sık çağrılmamalı
    } catch (e) {
      debugPrint('Failed to sync progress to backend: $e');
    }

    notifyListeners();
  }

  /// Kullanıcı adını backend'e kaydet ve leaderboard'u güncelle
  Future<void> updateDisplayName(String displayName) async {
    if (_authUser == null) {
      debugPrint('Update aborted: User not authenticated.');
      return;
    }

    try {
      final uid = _authUser!.uid;
      debugPrint('Syncing display name to backend for $uid: $displayName');

      await _apiService.updateUserProgress(
        userId: uid,
        displayName: displayName,
      );

      // Backend dosya yazma işleminin bitmesi için kısa bir süre bekle
      await Future.delayed(const Duration(milliseconds: 500));

      // İsim güncellendiği için leaderboard'u da yenile
      debugPrint('Refreshing leaderboard after name update...');
      await loadLeaderboard();
      debugPrint('Leaderboard refreshed.');
    } catch (e) {
      debugPrint('Failed to sync display name to backend: $e');
    }
  }

  Future<void> _updateDailyStats(String completedScenario) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    _todayConversations += 1;
    await prefs.setInt('conversations_$todayKey', _todayConversations);

    if (!_todayCompletedScenarios.contains(completedScenario)) {
      _todayCompletedScenarios.add(completedScenario);
      await prefs.setStringList(
        'scenarios_$todayKey',
        _todayCompletedScenarios,
      );
    }
  }

  void _updateLevel() {
    if (_progress == null) return;

    String newLevel = 'beginner';

    if (_progress!.totalConversations >= 50) {
      newLevel = 'advanced';
    } else if (_progress!.totalConversations >= 20) {
      newLevel = 'intermediate';
    }

    if (_progress!.currentLevel != newLevel) {
      _progress = _progress!.copyWith(currentLevel: newLevel);
    }
  }

  Future<void> resetAllStats() async {
    final prefs = await SharedPreferences.getInstance();

    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('usage_') ||
          key.startsWith('conversations_') ||
          key.startsWith('scenarios_')) {
        await prefs.remove(key);
      }
    }

    await prefs.setInt('total_conversations', 0);
    await prefs.setInt('total_time_minutes', 0);
    await prefs.setStringList('completed_scenarios', []);
    await prefs.setString('current_level', 'beginner');

    _todayUsedMinutes = 0;
    _weeklyUsedMinutes = 0;
    _todayConversations = 0;
    _todayCompletedScenarios = [];
    _todayScenariosStarted = 0;

    _progress = UserProgress(
      userId: userId,
      totalConversations: 0,
      totalTimeMinutes: 0,
      usedTimeMinutes: 0,
      currentLevel: 'beginner',
      completedScenarios: [],
    );

    notifyListeners();
  }

  Future<void> saveLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_level', level);
    notifyListeners();
  }

  Future<String> getLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_level') ?? 'beginner';
  }

  Future<Map<String, int>> getWeeklyUsageData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final Map<String, int> data = {};

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = '${date.year}-${date.month}-${date.day}';
      final dayName = _getDayName(date.weekday);
      data[dayName] = prefs.getInt('usage_$key') ?? 0;
    }

    return data;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Pzt';
      case 2:
        return 'Sal';
      case 3:
        return 'Çar';
      case 4:
        return 'Per';
      case 5:
        return 'Cum';
      case 6:
        return 'Cmt';
      case 7:
        return 'Paz';
      default:
        return '';
    }
  }
}
