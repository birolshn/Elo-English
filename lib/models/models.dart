import 'package:flutter/material.dart';

class Scenario {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final int estimatedTime;
  final String? customSystemPrompt;
  final String? greeting;
  final bool isCustom;

  Scenario({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedTime,
    this.customSystemPrompt,
    this.greeting,
    this.isCustom = false,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      difficulty: json['difficulty'],
      estimatedTime: json['estimated_time'] ?? 5,
      customSystemPrompt: json['custom_system_prompt'],
      greeting: json['greeting'],
      isCustom: json['is_custom'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'estimated_time': estimatedTime,
      'custom_system_prompt': customSystemPrompt,
      'greeting': greeting,
      'is_custom': isCustom,
    };
  }

  IconData get difficultyIcon {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Icons.eco_rounded;
      case 'intermediate':
        return Icons.timeline_rounded;
      case 'advanced':
        return Icons.military_tech_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  IconData get semanticIcon {
    if (isCustom) return Icons.auto_awesome_rounded;
    switch (id.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant_menu_rounded;
      case 'airport':
        return Icons.flight_takeoff_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'job_interview':
        return Icons.work_rounded;
      case 'small_talk':
        return Icons.people_rounded;
      case 'general':
        return Icons.forum_rounded;
      default:
        return difficultyIcon;
    }
  }

  Color get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF10B981);
      case 'intermediate':
        return const Color(0xFFF59E0B);
      case 'advanced':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

class WordPronunciationScore {
  final String word;
  final String ipa;
  final int score; // 0 - 100
  final String status; // 'perfect', 'good', 'needs_work'
  final String? tip;

  WordPronunciationScore({
    required this.word,
    required this.ipa,
    required this.score,
    required this.status,
    this.tip,
  });

  factory WordPronunciationScore.fromJson(Map<String, dynamic> json) {
    return WordPronunciationScore(
      word: json['word'] ?? '',
      ipa: json['ipa'] ?? '',
      score: (json['score'] as num?)?.toInt() ?? 80,
      status: json['status'] ?? 'good',
      tip: json['tip'],
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'ipa': ipa,
    'score': score,
    'status': status,
    'tip': tip,
  };

  Color get statusColor {
    switch (status) {
      case 'perfect':
        return const Color(0xFF10B981); // Emerald
      case 'good':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFFEF4444); // Red
    }
  }
}

class PronunciationResult {
  final int overallScore;
  final int fluencyScore;
  final List<WordPronunciationScore> words;
  final List<String> challengingSounds;
  final String encouragement;

  PronunciationResult({
    required this.overallScore,
    required this.fluencyScore,
    required this.words,
    this.challengingSounds = const [],
    required this.encouragement,
  });

  factory PronunciationResult.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'] as List<dynamic>? ?? [];
    return PronunciationResult(
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 80,
      fluencyScore: (json['fluency_score'] as num?)?.toInt() ?? 75,
      words: rawWords.map((w) => WordPronunciationScore.fromJson(w as Map<String, dynamic>)).toList(),
      challengingSounds: (json['challenging_sounds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      encouragement: json['encouragement'] ?? 'Keep speaking with confidence!',
    );
  }

  Map<String, dynamic> toJson() => {
    'overall_score': overallScore,
    'fluency_score': fluencyScore,
    'words': words.map((w) => w.toJson()).toList(),
    'challenging_sounds': challengingSounds,
    'encouragement': encouragement,
  };
}

class ConversationMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String>? grammarCorrections;
  final List<String>? vocabularySuggestions;
  final String? feedback;
  final PronunciationResult? pronunciationResult;
  final bool isStreaming;

  ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.grammarCorrections,
    this.vocabularySuggestions,
    this.feedback,
    this.pronunciationResult,
    this.isStreaming = false,
  });

  ConversationMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    List<String>? grammarCorrections,
    List<String>? vocabularySuggestions,
    String? feedback,
    PronunciationResult? pronunciationResult,
    bool? isStreaming,
  }) {
    return ConversationMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      grammarCorrections: grammarCorrections ?? this.grammarCorrections,
      vocabularySuggestions: vocabularySuggestions ?? this.vocabularySuggestions,
      feedback: feedback ?? this.feedback,
      pronunciationResult: pronunciationResult ?? this.pronunciationResult,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}

/// Model for Mistake Vault (Hata Defteri)
class MistakeItem {
  final String id;
  final String originalText;
  final String correctedText;
  final String explanation;
  final String rule;
  final String scenarioTitle;
  final DateTime timestamp;
  final bool isMastered;
  final int reviewCount;

  MistakeItem({
    required this.id,
    required this.originalText,
    required this.correctedText,
    required this.explanation,
    this.rule = 'Grammar & Accuracy',
    required this.scenarioTitle,
    required this.timestamp,
    this.isMastered = false,
    this.reviewCount = 0,
  });

  factory MistakeItem.fromJson(Map<String, dynamic> json) {
    return MistakeItem(
      id: json['id'],
      originalText: json['original_text'] ?? '',
      correctedText: json['corrected_text'] ?? '',
      explanation: json['explanation'] ?? '',
      rule: json['rule'] ?? 'Grammar & Accuracy',
      scenarioTitle: json['scenario_title'] ?? 'Conversation Practice',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isMastered: json['is_mastered'] ?? false,
      reviewCount: json['review_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'original_text': originalText,
    'corrected_text': correctedText,
    'explanation': explanation,
    'rule': rule,
    'scenario_title': scenarioTitle,
    'timestamp': timestamp.toIso8601String(),
    'is_mastered': isMastered,
    'review_count': reviewCount,
  };

  MistakeItem copyWith({
    String? id,
    String? originalText,
    String? correctedText,
    String? explanation,
    String? rule,
    String? scenarioTitle,
    DateTime? timestamp,
    bool? isMastered,
    int? reviewCount,
  }) {
    return MistakeItem(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      correctedText: correctedText ?? this.correctedText,
      explanation: explanation ?? this.explanation,
      rule: rule ?? this.rule,
      scenarioTitle: scenarioTitle ?? this.scenarioTitle,
      timestamp: timestamp ?? this.timestamp,
      isMastered: isMastered ?? this.isMastered,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}

/// Model for Spaced Repetition Vocabulary Bank (SRS Flashcards)
class SavedWord {
  final String id;
  final String word;
  final String meaning;
  final String ipa;
  final String exampleSentence;
  final DateTime savedAt;
  final DateTime nextReviewDate;
  final int intervalDays;
  final int repetitionCount;
  final double easeFactor; // Default 2.5 in SM-2

  SavedWord({
    required this.id,
    required this.word,
    required this.meaning,
    this.ipa = '',
    this.exampleSentence = '',
    required this.savedAt,
    required this.nextReviewDate,
    this.intervalDays = 1,
    this.repetitionCount = 0,
    this.easeFactor = 2.5,
  });

  factory SavedWord.fromJson(Map<String, dynamic> json) {
    return SavedWord(
      id: json['id'],
      word: json['word'],
      meaning: json['meaning'] ?? '',
      ipa: json['ipa'] ?? '',
      exampleSentence: json['example_sentence'] ?? '',
      savedAt: DateTime.tryParse(json['saved_at'] ?? '') ?? DateTime.now(),
      nextReviewDate: DateTime.tryParse(json['next_review_date'] ?? '') ?? DateTime.now(),
      intervalDays: json['interval_days'] ?? 1,
      repetitionCount: json['repetition_count'] ?? 0,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'meaning': meaning,
    'ipa': ipa,
    'example_sentence': exampleSentence,
    'saved_at': savedAt.toIso8601String(),
    'next_review_date': nextReviewDate.toIso8601String(),
    'interval_days': intervalDays,
    'repetition_count': repetitionCount,
    'ease_factor': easeFactor,
  };

  /// Hiç çalışılmamış (yeni) kelimeler hemen, diğerleri tarihi gelince tekrar edilir
  bool get isDueForReview => repetitionCount == 0 || DateTime.now().isAfter(nextReviewDate);
}

/// TOEFL 1-6 bandının eski 0-30 Speaking ölçeğindeki karşılığı (ETS karşılaştırma tablosu)
String toeflSpeakingLegacyRange(double band) {
  // Anahtar: bant x 2 (double anahtar const map'te kullanılamıyor)
  const table = {
    12: '28-30', 11: '27', 10: '25-26', 9: '23-24', 8: '20-22', 7: '18-19',
    6: '16-17', 5: '13-15', 4: '10-12', 3: '5-9', 2: '0-4',
  };
  final halfSteps = (band * 2).round().clamp(2, 12);
  return table[halfSteps] ?? '';
}

/// Academic Exam Type Enum
enum AcademicExamType {
  ielts,
  toefl,
}

extension AcademicExamTypeExtension on AcademicExamType {
  // Not: "name" adı kullanılamaz; Dart'ın yerleşik Enum.name getter'ı
  // extension'dan önce gelir ve 'ielts' gibi ham değeri döndürür.
  String get displayName {
    switch (this) {
      case AcademicExamType.ielts:
        return 'IELTS Speaking';
      case AcademicExamType.toefl:
        return 'TOEFL iBT Speaking';
    }
  }

  String get shortCode {
    switch (this) {
      case AcademicExamType.ielts:
        return 'ielts';
      case AcademicExamType.toefl:
        return 'toefl';
    }
  }

  /// Skorun üst sınırı (renk / ilerleme hesapları için)
  double get maxScore {
    switch (this) {
      case AcademicExamType.ielts:
        return 9.0;
      case AcademicExamType.toefl:
        // Ocak 2026'dan itibaren TOEFL iBT 1-6 bant ölçeği (CEFR uyumlu)
        return 6.0;
    }
  }

  /// PDF karnesinde gösterilen değerlendirme çerçevesi
  String get assessmentFramework {
    switch (this) {
      case AcademicExamType.ielts:
        return 'IELTS-Style Band Criteria (AI Estimate)';
      case AcademicExamType.toefl:
        return 'TOEFL iBT-Style 2026 Speaking (AI Estimate)';
    }
  }

  String get scoreScale {
    switch (this) {
      case AcademicExamType.ielts:
        return 'Band 0.0 - 9.0';
      case AcademicExamType.toefl:
        return 'Band 1 - 6';
    }
  }
}

/// Detailed Academic Exam & IELTS Score Report (PDF Ready)
class ExamReport {
  final AcademicExamType examType;
  final double score;
  final String scoreDisplay;
  final String cefrLevel;
  final String feedback;
  final Map<String, double> criteriaScores;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> actionableTips;
  final DateTime date;
  final String candidateName;

  ExamReport({
    required this.examType,
    required this.score,
    required this.scoreDisplay,
    required this.cefrLevel,
    required this.feedback,
    required this.criteriaScores,
    this.strengths = const [],
    this.weaknesses = const [],
    this.actionableTips = const [],
    required this.date,
    required this.candidateName,
  });

  factory ExamReport.fromJson(Map<String, dynamic> json, {AcademicExamType type = AcademicExamType.ielts, String candidateName = 'Student'}) {
    final rawCrit = json['criteria_scores'] as Map<String, dynamic>? ?? {};
    final critMap = rawCrit.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return ExamReport(
      examType: type,
      score: (json['score'] as num?)?.toDouble() ?? (json['band_score'] as num?)?.toDouble() ?? 6.5,
      scoreDisplay: json['score_display'] ?? 'Band ${json['band_score'] ?? 6.5}',
      cefrLevel: json['cefr_level'] ?? 'B2',
      feedback: json['feedback'] ?? '',
      criteriaScores: critMap.isNotEmpty
          ? critMap
          : {
              'Fluency & Coherence': (json['fluency_score'] as num?)?.toDouble() ?? 6.5,
              'Lexical Resource': (json['vocabulary_score'] as num?)?.toDouble() ?? 6.5,
              'Grammar Range': (json['grammar_score'] as num?)?.toDouble() ?? 6.0,
              'Pronunciation': (json['pronunciation_score'] as num?)?.toDouble() ?? 6.5,
            },
      strengths: (json['strengths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weaknesses: (json['weaknesses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? (json['improvement_areas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actionableTips: (json['actionable_tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? (json['recommended_practice'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      date: DateTime.now(),
      candidateName: candidateName,
    );
  }
}

class UserProgress {
  final String userId;
  final int totalConversations;
  final int totalTimeMinutes;
  final int usedTimeMinutes; // Kullanılan toplam süre
  final String currentLevel;
  final List<String> completedScenarios;
  final int weeklyXp;
  final int? rank;

  UserProgress({
    required this.userId,
    required this.totalConversations,
    required this.totalTimeMinutes,
    this.usedTimeMinutes = 0,
    required this.currentLevel,
    required this.completedScenarios,
    this.weeklyXp = 0,
    this.rank,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['user_id'],
      totalConversations: json['total_conversations'],
      totalTimeMinutes: json['total_time_minutes'],
      usedTimeMinutes: json['used_time_minutes'] ?? 0,
      currentLevel: json['current_level'],
      completedScenarios: List<String>.from(json['completed_scenarios']),
      weeklyXp: json['weekly_xp'] ?? 0,
      rank: json['rank'],
    );
  }

  UserProgress copyWith({
    String? userId,
    int? totalConversations,
    int? totalTimeMinutes,
    int? usedTimeMinutes,
    String? currentLevel,
    List<String>? completedScenarios,
    int? weeklyXp,
    int? rank,
  }) {
    return UserProgress(
      userId: userId ?? this.userId,
      totalConversations: totalConversations ?? this.totalConversations,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      usedTimeMinutes: usedTimeMinutes ?? this.usedTimeMinutes,
      currentLevel: currentLevel ?? this.currentLevel,
      completedScenarios: completedScenarios ?? this.completedScenarios,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      rank: rank ?? this.rank,
    );
  }
}

class PremiumStatus {
  final bool isPremium;
  final DateTime? expiryDate;
  final String? subscriptionType; // 'monthly', 'yearly'
  final String priceDisplay; // '249 TL' or '$9.99'
  final bool isTurkishUser;

  PremiumStatus({
    this.isPremium = false,
    this.expiryDate,
    this.subscriptionType,
    this.priceDisplay = '',
    this.isTurkishUser = false,
  });

  bool get isActive {
    if (!isPremium) return false;
    if (expiryDate == null) return false;
    return expiryDate!.isAfter(DateTime.now());
  }

  PremiumStatus copyWith({
    bool? isPremium,
    DateTime? expiryDate,
    String? subscriptionType,
    String? priceDisplay,
    bool? isTurkishUser,
  }) {
    return PremiumStatus(
      isPremium: isPremium ?? this.isPremium,
      expiryDate: expiryDate ?? this.expiryDate,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      priceDisplay: priceDisplay ?? this.priceDisplay,
      isTurkishUser: isTurkishUser ?? this.isTurkishUser,
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final int weeklyXp;
  final String? avatarUrl;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.weeklyXp,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'],
      userId: json['user_id'],
      displayName: json['display_name'],
      weeklyXp: json['weekly_xp'],
      avatarUrl: json['avatar_url'],
    );
  }
}
