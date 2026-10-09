import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class WordBankService {
  static const String _storageKey = 'elo_word_bank';
  static final WordBankService _instance = WordBankService._internal();
  factory WordBankService() => _instance;
  WordBankService._internal();

  Future<List<SavedWord>> getAllWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = json.decode(jsonStr);
      return list.map((item) => SavedWord.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error reading word bank: $e');
      return [];
    }
  }

  Future<List<SavedWord>> getDueWords() async {
    final all = await getAllWords();
    return all.where((w) => w.isDueForReview).toList();
  }

  Future<bool> isWordSaved(String word) async {
    final all = await getAllWords();
    final clean = word.toLowerCase().trim();
    return all.any((w) => w.word.toLowerCase().trim() == clean);
  }

  Future<SavedWord> saveWord({
    required String word,
    required String meaning,
    String ipa = '',
    String exampleSentence = '',
  }) async {
    final all = await getAllWords();
    final clean = word.trim();
    final existingIndex = all.indexWhere((w) => w.word.toLowerCase() == clean.toLowerCase());

    if (existingIndex != -1) {
      return all[existingIndex];
    }

    final newWord = SavedWord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      word: clean,
      meaning: meaning,
      ipa: ipa,
      exampleSentence: exampleSentence,
      savedAt: DateTime.now(),
      nextReviewDate: DateTime.now().add(const Duration(days: 1)),
      intervalDays: 1,
      repetitionCount: 0,
      easeFactor: 2.5,
    );

    all.insert(0, newWord);
    await _persist(all);
    return newWord;
  }

  /// SuperMemo (SM-2) Spaced Repetition Rating
  /// rating: 'again' (reset), 'hard', 'good', 'easy'
  /// Saf hesap: hem kaydetmede hem de buton etiketlerinde (önizleme) kullanılır.
  static ({int interval, int repetition, double ease}) computeNextReview(
    SavedWord current,
    String rating,
  ) {
    int nextInterval;
    int nextRepetition;
    double nextEaseFactor = current.easeFactor;

    switch (rating.toLowerCase()) {
      case 'again':
        nextRepetition = 0;
        nextInterval = 1;
        nextEaseFactor = (nextEaseFactor - 0.2).clamp(1.3, 3.0);
        break;
      case 'hard':
        nextRepetition = current.repetitionCount + 1;
        nextInterval = (current.intervalDays * 1.2).ceil().clamp(1, 180);
        nextEaseFactor = (nextEaseFactor - 0.15).clamp(1.3, 3.0);
        break;
      case 'good':
        // 1 gün, 3 gün, 7 gün, sonra ease factor ile büyür
        nextRepetition = current.repetitionCount + 1;
        if (nextRepetition == 1) {
          nextInterval = 1;
        } else if (nextRepetition == 2) {
          nextInterval = 3;
        } else if (nextRepetition == 3) {
          nextInterval = 7;
        } else {
          nextInterval = (current.intervalDays * nextEaseFactor).round().clamp(1, 365);
        }
        break;
      case 'easy':
      default:
        nextRepetition = current.repetitionCount + 1;
        if (nextRepetition == 1) {
          nextInterval = 3;
        } else if (nextRepetition == 2) {
          nextInterval = 7;
        } else {
          nextInterval = (current.intervalDays * (nextEaseFactor * 1.3)).round().clamp(1, 365);
        }
        nextEaseFactor = (nextEaseFactor + 0.15).clamp(1.3, 3.0);
        break;
    }
    return (interval: nextInterval, repetition: nextRepetition, ease: nextEaseFactor);
  }

  Future<void> reviewWord(String id, String rating) async {
    final all = await getAllWords();
    final index = all.indexWhere((w) => w.id == id);
    if (index == -1) return;

    final current = all[index];
    final next = computeNextReview(current, rating);
    final nextInterval = next.interval;
    final nextRepetition = next.repetition;
    final nextEaseFactor = next.ease;

    final updated = SavedWord(
      id: current.id,
      word: current.word,
      meaning: current.meaning,
      ipa: current.ipa,
      exampleSentence: current.exampleSentence,
      savedAt: current.savedAt,
      nextReviewDate: DateTime.now().add(Duration(days: nextInterval)),
      intervalDays: nextInterval,
      repetitionCount: nextRepetition,
      easeFactor: nextEaseFactor,
    );

    all[index] = updated;
    await _persist(all);
  }

  Future<void> deleteWord(String id) async {
    final all = await getAllWords();
    all.removeWhere((w) => w.id == id);
    await _persist(all);
  }

  Future<void> _persist(List<SavedWord> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = list.map((w) => w.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }
}
