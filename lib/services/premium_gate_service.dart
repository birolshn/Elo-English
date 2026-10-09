import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Ücretsiz kullanıcıların premium özellikleri "tadabilmesi" için kotalar:
/// - Haftada 1 ücretsiz IELTS / TOEFL deneme sınavı
/// - Günde 3 dakika ücretsiz telefon araması modu
/// - "Harika oturum" teklifi günde en fazla 1 kez
class PremiumGateService {
  PremiumGateService({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  static const Duration freeExamInterval = Duration(days: 7);
  static const int freeCallSecondsPerDay = 180;

  static const String _freeExamKey = 'free_exam_last_used_at';
  static const String _callSecondsPrefix = 'call_mode_seconds_';
  static const String _sessionWinKey = 'session_win_prompt_date';

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ─── Haftalık ücretsiz sınav ─────────────────────────────────────────

  /// Bir sonraki ücretsiz sınavın açılacağı an; şu an hakkı varsa null
  Future<DateTime?> nextFreeExamAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_freeExamKey);
    if (raw == null) return null;
    final lastUsed = DateTime.tryParse(raw);
    if (lastUsed == null) return null;
    final next = lastUsed.add(freeExamInterval);
    return _now().isBefore(next) ? next : null;
  }

  Future<bool> canStartFreeExam() async => (await nextFreeExamAt()) == null;

  Future<void> markFreeExamUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_freeExamKey, _now().toIso8601String());
  }

  // ─── Günlük ücretsiz arama dakikası ──────────────────────────────────

  Future<int> remainingFreeCallSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt('$_callSecondsPrefix${_dayKey(_now())}') ?? 0;
    return max(0, freeCallSecondsPerDay - used);
  }

  Future<void> addCallSeconds(int seconds) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_callSecondsPrefix${_dayKey(_now())}';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + seconds);
  }

  // ─── "Harika oturum" teklifi (günde 1) ────────────────────────────────

  Future<bool> shouldShowSessionWin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionWinKey) != _dayKey(_now());
  }

  Future<void> markSessionWinShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionWinKey, _dayKey(_now()));
  }
}
