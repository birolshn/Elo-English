import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class MistakeVaultService {
  static const String _storageKey = 'elo_mistake_vault';
  static final MistakeVaultService _instance = MistakeVaultService._internal();
  factory MistakeVaultService() => _instance;
  MistakeVaultService._internal();

  Future<List<MistakeItem>> getMistakes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = json.decode(jsonStr);
      return list.map((item) => MistakeItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error reading mistake vault: $e');
      return [];
    }
  }

  Future<void> saveMistake({
    required String originalText,
    required String correctedText,
    required String explanation,
    String rule = 'Grammar & Accuracy',
    required String scenarioTitle,
  }) async {
    try {
      final mistakes = await getMistakes();
      
      // Avoid duplicate exact mistakes
      final exists = mistakes.any((m) =>
          m.originalText.toLowerCase().trim() == originalText.toLowerCase().trim() &&
          m.correctedText.toLowerCase().trim() == correctedText.toLowerCase().trim());
      if (exists) return;

      final newItem = MistakeItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        originalText: originalText,
        correctedText: correctedText,
        explanation: explanation,
        rule: rule,
        scenarioTitle: scenarioTitle,
        timestamp: DateTime.now(),
        isMastered: false,
        reviewCount: 0,
      );

      mistakes.insert(0, newItem);
      await _persist(mistakes);
    } catch (e) {
      debugPrint('Error saving mistake: $e');
    }
  }

  /// Automatically parses and records grammar corrections from AI responses
  Future<void> autoRecordFromAiCorrections({
    required List<String> corrections,
    required String userMessage,
    required String scenarioTitle,
  }) async {
    if (corrections.isEmpty) return;

    for (final corr in corrections) {
      final parsed = parseCorrection(corr, userMessage);
      if (parsed == null) continue;

      await saveMistake(
        originalText: parsed.original,
        correctedText: parsed.corrected,
        explanation: corr,
        rule: parsed.rule,
        scenarioTitle: scenarioTitle,
      );
    }
  }

  static final RegExp _noMistakePattern = RegExp(
    r'^\W*(none|n/a|no (significant |major )?(grammar )?(mistakes?|errors?|corrections?)\b|perfect)',
    caseSensitive: false,
  );
  static final RegExp _arrowPattern = RegExp(r'\s*(?:->|=>|➔|→|⟶)\s*');
  static final RegExp _insteadOfPattern = RegExp(r'\s+(?:instead of|rather than)\s+', caseSensitive: false);
  static final RegExp _leadingQuotes = RegExp('^["\'“”‘’`]+');
  static final RegExp _trailingQuotes = RegExp('["\'“”‘’`]+[.,;:]*\$');

  /// Baştaki/sondaki tırnakları temizler; "I'd" gibi kelime içi kesmeleri korur
  static String _stripQuotes(String s) {
    return s.trim().replaceAll(_leadingQuotes, '').replaceAll(_trailingQuotes, '').trim();
  }

  /// AI düzeltmesini (ör. "'I have went' -> 'I went' (Past Simple)") ayrıştırır.
  /// "Hata yok" türü cevaplar için null döner.
  static ({String original, String corrected, String rule})? parseCorrection(
    String correction,
    String userMessage,
  ) {
    var body = correction.trim();
    if (body.isEmpty || _noMistakePattern.hasMatch(body)) return null;

    String rule = 'Grammar Rule';
    final ruleMatch = RegExp(r'\(([^()]+)\)\s*\.?$').firstMatch(body);
    if (ruleMatch != null) {
      rule = ruleMatch.group(1)!.replaceFirst(RegExp(r'^rule:\s*', caseSensitive: false), '').trim();
      body = body.substring(0, ruleMatch.start).trim();
    }

    String original = userMessage;
    String corrected = correction;

    if (_arrowPattern.hasMatch(body)) {
      final parts = body.split(_arrowPattern);
      original = _stripQuotes(parts[0].replaceFirst(RegExp(r'^you said:?\s*', caseSensitive: false), ''));
      corrected = _stripQuotes(parts[1]);
    } else if (_insteadOfPattern.hasMatch(body)) {
      // "Use 'X' instead of 'Y'": X doğru, Y kullanıcının hatası
      final parts = body.split(_insteadOfPattern);
      corrected = _stripQuotes(parts[0].replaceFirst(
          RegExp(r'^(you should )?(use|say|try|write)\s+', caseSensitive: false), ''));
      original = _stripQuotes(parts[1]);
    }

    if (original.isEmpty || corrected.isEmpty) {
      original = userMessage;
      corrected = correction;
    }
    return (original: original, corrected: corrected, rule: rule);
  }

  Future<void> markAsMastered(String id) async {
    final mistakes = await getMistakes();
    final index = mistakes.indexWhere((m) => m.id == id);
    if (index != -1) {
      final current = mistakes[index];
      mistakes[index] = current.copyWith(
        isMastered: true,
        reviewCount: current.reviewCount + 1,
      );
      await _persist(mistakes);
    }
  }

  Future<void> recordPracticeResult(String id, bool isCorrect) async {
    final mistakes = await getMistakes();
    final index = mistakes.indexWhere((m) => m.id == id);
    if (index != -1) {
      final current = mistakes[index];
      mistakes[index] = current.copyWith(
        isMastered: isCorrect,
        reviewCount: current.reviewCount + 1,
      );
      await _persist(mistakes);
    }
  }

  Future<void> deleteMistake(String id) async {
    final mistakes = await getMistakes();
    mistakes.removeWhere((m) => m.id == id);
    await _persist(mistakes);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _persist(List<MistakeItem> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = list.map((m) => m.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }
}
