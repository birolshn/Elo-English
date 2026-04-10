import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/premium_popup.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<String, int> _weeklyData = {};
  List<Scenario> _scenarios = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sayfa her görüntülendiğinde verileri yenile
    _loadData();
  }

  Future<void> _loadData() async {
    // Haftalık veri yükle
    final userProvider = context.read<UserProvider>();
    final data = await userProvider.getWeeklyUsageData();

    // Senaryoları yükle
    try {
      final scenarios = await _apiService.getScenarios();
      if (mounted) {
        setState(() {
          _weeklyData = data;
          _scenarios = scenarios;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weeklyData = data;
        });
      }
    }
  }

  String _getScenarioTitle(String scenarioId) {
    final scenario = _scenarios.where((s) => s.id == scenarioId).firstOrNull;
    return scenario?.title ?? scenarioId;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final premiumProvider = context.watch<PremiumProvider>();
    final progress = userProvider.progress;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Curved header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 16,
                24,
                24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withBlue(220)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Your Progress',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Premium badge
                  if (premiumProvider.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              child:
                  progress == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLevelCard(context, progress.currentLevel),
                            const SizedBox(height: 28),
                            _buildUsageStatsSection(context, userProvider),
                            const SizedBox(height: 28),
                            _buildWeeklyChartSection(context),
                            const SizedBox(height: 28),
                            _buildPerformanceSection(context, progress),
                            const SizedBox(height: 28),
                            _buildAchievementsSection(context, progress),
                            const SizedBox(height: 28),
                            _buildCompletedScenariosSection(context, progress),
                            const SizedBox(height: 28),
                            if (!premiumProvider.isPremium)
                              _buildPremiumBanner(context, premiumProvider),
                            if (!premiumProvider.isPremium)
                              const SizedBox(height: 28),
                            _buildMotivationalMessage(context, progress),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStatsSection(
    BuildContext context,
    UserProvider userProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Usage Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.today, color: Colors.white, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      '${userProvider.todayUsedMinutes}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'minutes today',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFFB855F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.date_range, color: Colors.white, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      '${userProvider.weeklyUsedMinutes}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'minutes this week',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyChartSection(BuildContext context) {
    final maxValue =
        _weeklyData.values.isEmpty
            ? 1
            : _weeklyData.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children:
                _weeklyData.entries.map((entry) {
                  final height =
                      maxValue > 0 ? (entry.value / maxValue) * 80 : 0.0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: entry.value == 0
                            ? 4
                            : (height < 16 ? 16 : height),
                        decoration: BoxDecoration(
                          gradient: entry.value == 0
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF34D399),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                          color: entry.value == 0 ? Colors.grey.shade200 : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumBanner(
    BuildContext context,
    PremiumProvider premiumProvider,
  ) {
    return GestureDetector(
      onTap: () => showPremiumPopup(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.amber,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For unlimited practice, ${premiumProvider.monthlyPrice}/month',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, String level) {
    final levelInfo = _getLevelInfo(level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(levelInfo['icon']! as IconData, size: 72, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Your Level',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            levelInfo['name']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            levelInfo['description']!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getLevelInfo(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return {
          'icon': Icons.eco_rounded,
          'name': 'Beginner',
          'description':
              'You made a great start on your English journey. Keep moving towards your goals!',
        };
      case 'intermediate':
        return {
          'icon': Icons.timeline_rounded,
          'name': 'Intermediate',
          'description':
              'Remarkable progress! Your speaking skills are improving.',
        };
      case 'advanced':
        return {
          'icon': Icons.military_tech_rounded,
          'name': 'Advanced',
          'description':
              'Excellent! You are speaking English fluently and with confidence.',
        };
      default:
        return {
          'icon': Icons.school_rounded,
          'name': level,
          'description': 'Keep progressing on your learning journey!',
        };
    }
  }

  Widget _buildPerformanceSection(BuildContext context, progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'General Performance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),

        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildPerformanceCard(
              context,
              icon: Icons.schedule,
              title: 'Total Practice',
              value: '${progress.totalTimeMinutes}',
              unit: 'minutes',
              color: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            ),
            _buildPerformanceCard(
              context,
              icon: Icons.chat_bubble_outline,
              title: 'Completed',
              value: '${progress.totalConversations}',
              unit: 'chats',
              color: const Color(0xFF9333EA),
              bgColor: const Color(0xFFFAF5FF),
            ),
            _buildPerformanceCard(
              context,
              icon: Icons.trending_up,
              title: 'Scenarios',
              value: '${progress.completedScenarios.length}',
              unit: 'completed',
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFF0FDF4),
            ),
            _buildPerformanceCard(
              context,
              icon: Icons.local_fire_department,
              title: 'Motivation',
              value: '${(progress.totalConversations ~/ 10) + 1}',
              unit: 'level',
              color: const Color(0xFFF97316),
              bgColor: const Color(0xFFFFF7ED),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context, progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        // Konuşma bazlı başarılar
        Row(
          children: [
            _buildAchievementBadge(
              Icons.track_changes_rounded,
              'First Step',
              progress.totalConversations >= 1,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.star_rounded,
              '5 Chats',
              progress.totalConversations >= 5,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.local_fire_department_rounded,
              '10 Chats',
              progress.totalConversations >= 10,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.emoji_events_rounded,
              '25 Chats',
              progress.totalConversations >= 25,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Süre bazlı başarılar
        Row(
          children: [
            _buildAchievementBadge(
              Icons.timer_outlined,
              '30 Minutes',
              progress.totalTimeMinutes >= 30,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.schedule_rounded,
              '1 Hour',
              progress.totalTimeMinutes >= 60,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.diamond_outlined,
              '5 Hours',
              progress.totalTimeMinutes >= 300,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.workspace_premium_rounded,
              '10 Hours',
              progress.totalTimeMinutes >= 600,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Senaryo bazlı başarılar
        Row(
          children: [
            _buildAchievementBadge(
              Icons.menu_book_rounded,
              '1 Scenario',
              progress.completedScenarios.length >= 1,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.library_books_rounded,
              '3 Scenarios',
              progress.completedScenarios.length >= 3,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.school_rounded,
              '5 Scenarios',
              progress.completedScenarios.length >= 5,
            ),
            const SizedBox(width: 12),
            _buildAchievementBadge(
              Icons.stars_rounded,
              'All Scenarios',
              _scenarios.isNotEmpty &&
                  progress.completedScenarios.length >= _scenarios.length,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(
    IconData iconData,
    String label,
    bool unlocked,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xFFFDF2F8) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                unlocked
                    ? const Color(0xFFEC4899).withOpacity(0.3)
                    : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              iconData,
              size: 28,
              color: unlocked ? const Color(0xFFEC4899) : Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    unlocked ? const Color(0xFFEC4899) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedScenariosSection(BuildContext context, progress) {
    if (progress.completedScenarios.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Scenarios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 12),
                Text(
                  'No scenarios completed yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete conversation practices to get started',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Completed Scenarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              progress.completedScenarios
                  .map<Widget>(
                    (scenario) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getScenarioTitle(scenario),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildMotivationalMessage(BuildContext context, progress) {
    final messages = [
      (
        '🚀',
        'Great Progress!',
        "If you keep up this pace, you'll become fluent in English.",
      ),
      (
        '💪',
        'Better Every Day!',
        'You are achieving success through consistent practice.',
      ),
      (
        '🌟',
        'On the Path to Success!',
        'You are taking steady steps towards your goals.',
      ),
      ('🎯', 'Getting Closer!', 'With this motivation, you can go very far.'),
      ('🏅', 'Great Work!', 'Your English skills are improving rapidly.'),
    ];

    final randomMessage =
        messages[progress.totalConversations % messages.length];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEC4899).withOpacity(0.85),
            const Color(0xFF9333EA).withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(randomMessage.$1, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      randomMessage.$2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      randomMessage.$3,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
