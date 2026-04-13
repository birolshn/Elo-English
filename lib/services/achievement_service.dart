import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const Achievement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static const List<String> _motivationalQuotes = [
    "Success is the sum of small efforts repeated day in and day out.",
    "The expert in anything was once a beginner.",
    "Your only limit is the one you set for yourself.",
    "Every master was once a disaster. Keep going!",
    "Consistency is the key to mastery.",
    "You're building something amazing, one step at a time.",
    "The best time to start was yesterday. The next best time is now.",
    "Believe in yourself. You're closer than you think.",
  ];

  static final List<Achievement> allAchievements = [
    const Achievement(id: 'first_step', title: 'First Step', subtitle: 'Complete your first chat', icon: Icons.track_changes_rounded, color: Color(0xFF10B981)),
    const Achievement(id: '5_chats', title: '5 Chats', subtitle: 'Complete 5 conversations', icon: Icons.star_rounded, color: Color(0xFFF59E0B)),
    const Achievement(id: '10_chats', title: '10 Chats', subtitle: 'Complete 10 conversations', icon: Icons.local_fire_department_rounded, color: Color(0xFFEF4444)),
    const Achievement(id: '25_chats', title: '25 Chats', subtitle: 'Complete 25 conversations', icon: Icons.emoji_events_rounded, color: Color(0xFF9333EA)),
    const Achievement(id: '30_min', title: '30 Minutes', subtitle: 'Practice for 30 minutes', icon: Icons.timer_outlined, color: Color(0xFF2563EB)),
    const Achievement(id: '1_hour', title: '1 Hour', subtitle: 'Practice for 1 hour', icon: Icons.schedule_rounded, color: Color(0xFF7C3AED)),
    const Achievement(id: '5_hours', title: '5 Hours', subtitle: 'Practice for 5 hours', icon: Icons.diamond_outlined, color: Color(0xFFEC4899)),
    const Achievement(id: '10_hours', title: '10 Hours', subtitle: 'Practice for 10 hours', icon: Icons.workspace_premium_rounded, color: Color(0xFFFFD700)),
    const Achievement(id: '1_scenario', title: '1 Scenario', subtitle: 'Complete 1 scenario', icon: Icons.menu_book_rounded, color: Color(0xFF10B981)),
    const Achievement(id: '3_scenarios', title: '3 Scenarios', subtitle: 'Complete 3 scenarios', icon: Icons.library_books_rounded, color: Color(0xFFF59E0B)),
    const Achievement(id: '5_scenarios', title: '5 Scenarios', subtitle: 'Complete 5 scenarios', icon: Icons.school_rounded, color: Color(0xFF2563EB)),
    const Achievement(id: 'all_scenarios', title: 'All Scenarios', subtitle: 'Complete every scenario', icon: Icons.stars_rounded, color: Color(0xFFFFD700)),
    const Achievement(id: 'top_50', title: 'Top 50', subtitle: 'Reach the leaderboard top 50', icon: Icons.leaderboard_rounded, color: Color(0xFFEC4899)),
  ];

  Future<Set<String>> getUnlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('unlocked_achievements') ?? []).toSet();
  }

  Future<void> _saveUnlockedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_achievements', ids.toList());
  }

  Future<List<Achievement>> checkAndUnlock({
    required int totalConversations,
    required int totalTimeMinutes,
    required int completedScenariosCount,
    required int totalScenariosCount,
    required int? rank,
  }) async {
    final unlocked = await getUnlockedIds();
    final newlyUnlocked = <Achievement>[];

    final checks = <String, bool>{
      'first_step': totalConversations >= 1,
      '5_chats': totalConversations >= 5,
      '10_chats': totalConversations >= 10,
      '25_chats': totalConversations >= 25,
      '30_min': totalTimeMinutes >= 30,
      '1_hour': totalTimeMinutes >= 60,
      '5_hours': totalTimeMinutes >= 300,
      '10_hours': totalTimeMinutes >= 600,
      '1_scenario': completedScenariosCount >= 1,
      '3_scenarios': completedScenariosCount >= 3,
      '5_scenarios': completedScenariosCount >= 5,
      'all_scenarios': totalScenariosCount > 0 && completedScenariosCount >= totalScenariosCount,
      'top_50': rank != null && rank <= 50,
    };

    for (final entry in checks.entries) {
      if (entry.value && !unlocked.contains(entry.key)) {
        unlocked.add(entry.key);
        final achievement = allAchievements.firstWhere((a) => a.id == entry.key);
        newlyUnlocked.add(achievement);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlockedIds(unlocked);
    }

    return newlyUnlocked;
  }

  Future<int?> getPreviousRank() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('previous_rank');
  }

  Future<void> savePreviousRank(int? rank) async {
    final prefs = await SharedPreferences.getInstance();
    if (rank != null) {
      await prefs.setInt('previous_rank', rank);
    }
  }

  String getRandomMotivationalQuote() {
    return _motivationalQuotes[DateTime.now().millisecondsSinceEpoch % _motivationalQuotes.length];
  }

  static void showAchievementPopup(BuildContext context, Achievement achievement, String quote) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'achievement',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: curved,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    achievement.color.withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: achievement.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(achievement.icon, size: 48, color: achievement.color),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Achievement Unlocked!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement.title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: achievement.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.subtitle,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            quote,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: achievement.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void showLeaderboardEntryPopup(BuildContext context, int rank) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'leaderboard',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: curved,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFDF2F8), Colors.white],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 48, color: Color(0xFFFFD700)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'You Made the Leaderboard!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rank #$rank',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFEC4899)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You're among the top 50 learners this week. Keep pushing to climb higher!",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("Let's Go!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
