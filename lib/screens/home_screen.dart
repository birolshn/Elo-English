import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/premium_popup.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<UserProvider>().loadProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 24,
                  24,
                  32,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                FirebaseAuth.instance.currentUser?.displayName?.split(' ').first != null && FirebaseAuth.instance.currentUser!.displayName!.isNotEmpty
                                    ? 'Welcome, ${FirebaseAuth.instance.currentUser!.displayName!.split(' ').first}'
                                    : 'Welcome',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Keep reaching your learning goals.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed:
                              () => Navigator.pushNamed(
                                context,
                                '/notifications',
                              ),
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Card
                    _buildStatsCard(context),

                    const SizedBox(height: 24),

                    // Section Title
                    const Text(
                      'What would you like to do?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main Action Card - Konuşma Başlat
                    _buildMainActionCard(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      title: 'Start Conversation',
                      subtitle: 'Practice realistic dialogues with your AI tutor',
                      color: const Color(0xFF0EA5E9),
                      onTap: () => Navigator.pushNamed(context, '/scenarios'),
                    ),

                    const SizedBox(height: 12),

                    // IELTS Mock Test Action
                    _buildMainActionCard(
                      context,
                      icon: Icons.record_voice_over_rounded,
                      title: 'IELTS Speaking Simulator',
                      subtitle: 'Part 1, 2 & 3 mock tests with AI examiner',
                      color: const Color(0xFF9333EA),
                      isPremium: true,
                      onTap: () {
                        final isPremium =
                            context.read<PremiumProvider>().isPremium;
                        if (isPremium) {
                          Navigator.pushNamed(context, '/ielts-exam');
                        } else {
                          showPremiumPopup(context, triggerContext: 'ielts');
                        }
                      },
                    ),

                    // Space at bottom
                    const SizedBox(height: 16),

                    const SizedBox(height: 32),

                    // Daily Tip Card
                    _buildTipCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final progress = userProvider.progress;

    String levelDisplay = 'Beginner';
    Color levelColor = const Color(0xFF10B981);

    if (progress != null) {
      switch (progress.currentLevel.toLowerCase()) {
        case 'intermediate':
          levelColor = const Color(0xFFF59E0B);
          levelDisplay = 'Intermediate';
          break;
        case 'advanced':
          levelColor = const Color(0xFFEF4444);
          levelDisplay = 'Advanced';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Today\'s Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  levelDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: levelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.access_time_rounded,
                  value: '${userProvider.todayUsedMinutes}',
                  label: 'minutes',
                  color: const Color(0xFF3B82F6),
                ),
              ),
              Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.forum_rounded,
                  value: '${userProvider.todayConversations}',
                  label: 'conversations',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.check_circle_rounded,
                  value: '${userProvider.todayCompletedScenarios.length}',
                  label: 'scenarios',
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildMainActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isPremium = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 2),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(BuildContext context) {
    final tips = [
      'Practice at least 10 minutes every day to build a strong habit!',
      'Don\'t be afraid of making mistakes; they are proof that you are trying.',
      'Record your voice and listen to it later to improve your pronunciation.',
      'Learning 5 new words a day equals 1825 words a year!',
      'Try to think in English instead of translating from your native language.',
      'Watch your favorite movies or shows with English subtitles.',
      'Speak clearly and confidently; fluency comes with practice.'
    ];
    final currentDayIndex = DateTime.now().weekday - 1; // 1-7 to 0-6

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFCD34D).withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tip of the Day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tips[currentDayIndex],
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
