import 'package:flutter/material.dart';

class Scenario {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final int estimatedTime;

  Scenario({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedTime,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      difficulty: json['difficulty'],
      estimatedTime: json['estimated_time'],
    );
  }

  String get difficultyEmoji {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return '🌱';
      case 'intermediate':
        return '🌿';
      case 'advanced':
        return '🌳';
      default:
        return '📚';
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

class ConversationMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String>? grammarCorrections;
  final List<String>? vocabularySuggestions;
  final String? feedback;

  ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.grammarCorrections,
    this.vocabularySuggestions,
    this.feedback,
  });

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
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
