import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/achievement_service.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserProgress? _progress;
  User? _authUser;
  String _userId = '';
  bool _isLoading = false;

  final AchievementService _achievementService = AchievementService();

  List<LeaderboardEntry> _leaderboard = [];
  int? _currentRank;
  bool _isLeaderboardLoading = false;
  List<Achievement> _pendingAchievements = [];
  bool _showLeaderboardEntryPopup = false;
  bool _showLeaderboardDropNotification = false;

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
  List<Achievement> get pendingAchievements => _pendingAchievements;
  bool get showLeaderboardEntryPopup => _showLeaderboardEntryPopup;
  bool get showLeaderboardDropNotification => _showLeaderboardDropNotification;

  void clearPendingAchievements() {
    _pendingAchievements = [];
    notifyListeners();
  }

  void clearLeaderboardEntryPopup() {
    _showLeaderboardEntryPopup = false;
    notifyListeners();
  }

  void clearLeaderboardDropNotification() {
    _showLeaderboardDropNotification = false;
    notifyListeners();
  }

  int get remainingDailyScenarios =>
      (dailyScenarioLimit - _todayScenariosStarted).clamp(
        0,
        dailyScenarioLimit,
      );

  /// Firestore'daki kullanıcı doküman referansı
  DocumentReference _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

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

      // 2. Firestore'dan güncel verileri çek ve senkronize et
      try {
        final doc = await _userDoc(userId).get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;

          final firestoreProgress = UserProgress(
            userId: userId,
            totalConversations: data['total_conversations'] ?? 0,
            totalTimeMinutes: data['total_time_minutes'] ?? 0,
            usedTimeMinutes: data['used_time_minutes'] ?? 0,
            currentLevel: data['current_level'] ?? 'beginner',
            completedScenarios:
                List<String>.from(data['completed_scenarios'] ?? []),
            weeklyXp: data['weekly_xp'] ?? 0,
          );

          // Firestore verisi daha yeniyse merge et
          if (firestoreProgress.totalConversations >
              (_progress?.totalConversations ?? 0)) {
            _progress = firestoreProgress;
            // Local'i güncelle
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(
              'total_conversations',
              _progress!.totalConversations,
            );
            await prefs.setInt(
              'total_time_minutes',
              _progress!.totalTimeMinutes,
            );
            await prefs.setStringList(
              'completed_scenarios',
              _progress!.completedScenarios,
            );
            await prefs.setString('current_level', _progress!.currentLevel);
          }
        } else {
          // Firestore'da kullanıcı yoksa oluştur
          await _createFirestoreUser();
        }
      } catch (e) {
        debugPrint('Firestore sync error: $e');
        // Firestore hatası olsa bile local veriyle devam et
      }

      _updateLevel();

      // Kullanıcının weekly rank'ini hesapla
      await loadCurrentUserRank();
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

  /// Firestore'da yeni kullanıcı dokümanı oluştur
  Future<void> _createFirestoreUser() async {
    await _userDoc(userId).set({
      'user_id': userId,
      'total_conversations': _progress?.totalConversations ?? 0,
      'total_time_minutes': _progress?.totalTimeMinutes ?? 0,
      'used_time_minutes': _progress?.usedTimeMinutes ?? 0,
      'weekly_xp': 0,
      'current_level': _progress?.currentLevel ?? 'beginner',
      'completed_scenarios': _progress?.completedScenarios ?? [],
      'display_name': _authUser?.displayName ?? 'User',
      'last_active': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Leaderboard verilerini Firestore'dan yükle
  Future<void> loadLeaderboard() async {
    _isLeaderboardLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('weekly_xp', descending: true)
          .limit(50)
          .get();

      _leaderboard = [];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final data = snapshot.docs[i].data();
        final entry = LeaderboardEntry(
          rank: i + 1,
          userId: snapshot.docs[i].id,
          displayName: data['display_name'] ?? 'User',
          weeklyXp: data['weekly_xp'] ?? 0,
          avatarUrl: data['avatar_url'],
        );
        _leaderboard.add(entry);
      }

      // Kullanıcının güncel sırasını bul
      final myEntry =
          _leaderboard.where((e) => e.userId == userId).firstOrNull;
      if (myEntry != null) {
        _currentRank = myEntry.rank;
      } else {
          await loadCurrentUserRank();
      }

      await _checkLeaderboardRankChange();
    } catch (e) {
      debugPrint('Leaderboard loading error: $e');
    } finally {
      _isLeaderboardLoading = false;
      notifyListeners();
    }
  }

  /// Kullanıcının gerçek weekly rank'ini Firestore'dan hesapla
  /// Leaderboard limitinden bağımsız olarak çalışır
  Future<void> loadCurrentUserRank() async {
    try {
      // 1. Kullanıcının weekly_xp değerini al
      final userDoc = await _userDoc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>?;
      final userXp = userData?['weekly_xp'] ?? 0;

      // 2. Daha yüksek XP'ye sahip kullanıcı sayısını say
      final countSnapshot = await _firestore
          .collection('users')
          .where('weekly_xp', isGreaterThan: userXp)
          .count()
          .get();

      _currentRank = (countSnapshot.count ?? 0) + 1;
      notifyListeners();
    } catch (e) {
      debugPrint('Rank calculation error: $e');
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

    // Firestore Sync
    try {
      // Her dakika 10 XP olsun
      final xpEarned = addedMinutes * 10;

      await _userDoc(userId).set({
        'total_conversations': _progress!.totalConversations,
        'total_time_minutes': _progress!.totalTimeMinutes,
        'used_time_minutes': _progress!.usedTimeMinutes,
        'completed_scenarios': newCompletedScenarios,
        'current_level': _progress!.currentLevel,
        'weekly_xp': FieldValue.increment(xpEarned),
        'display_name': _authUser?.displayName ?? 'User',
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync progress to Firestore: $e');
    }

    await _checkAchievements();
    notifyListeners();
  }

  /// Kullanıcı adını Firestore'a kaydet ve leaderboard'u güncelle
  Future<void> updateDisplayName(String displayName) async {
    if (_authUser == null) {
      debugPrint('Update aborted: User not authenticated.');
      return;
    }

    try {
      final uid = _authUser!.uid;
      debugPrint('Syncing display name to Firestore for $uid: $displayName');

      await _userDoc(uid).set({
        'display_name': displayName,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // İsim güncellendiği için leaderboard'u da yenile
      debugPrint('Refreshing leaderboard after name update...');
      await loadLeaderboard();
      debugPrint('Leaderboard refreshed.');
    } catch (e) {
      debugPrint('Failed to sync display name to Firestore: $e');
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

  Future<void> _checkAchievements() async {
    if (_progress == null) return;
    final newlyUnlocked = await _achievementService.checkAndUnlock(
      totalConversations: _progress!.totalConversations,
      totalTimeMinutes: _progress!.totalTimeMinutes,
      completedScenariosCount: _progress!.completedScenarios.length,
      totalScenariosCount: 0,
      rank: _currentRank,
    );
    if (newlyUnlocked.isNotEmpty) {
      _pendingAchievements = newlyUnlocked;
      notifyListeners();
    }
  }

  Future<void> _checkLeaderboardRankChange() async {
    final previousRank = await _achievementService.getPreviousRank();
    final currentRank = _currentRank;

    if (currentRank != null && currentRank <= 50) {
      if (previousRank == null || previousRank > 50) {
        _showLeaderboardEntryPopup = true;
      }
    } else if (currentRank != null && currentRank > 50) {
      if (previousRank != null && previousRank <= 50) {
        _showLeaderboardDropNotification = true;
      }
    }

    if (currentRank != null) {
      await _achievementService.savePreviousRank(currentRank);
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

    // Firestore'daki veriyi de sıfırla
    try {
      await _userDoc(userId).set({
        'total_conversations': 0,
        'total_time_minutes': 0,
        'used_time_minutes': 0,
        'weekly_xp': 0,
        'current_level': 'beginner',
        'completed_scenarios': [],
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to reset Firestore data: $e');
    }

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
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}
