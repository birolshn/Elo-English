import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/achievement_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'account_screen.dart';
import 'leaderboard_screen.dart';
import 'progress_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LeaderboardScreen(),
    ProgressScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForPopups();
    });
  }

  void _listenForPopups() {
    final userProvider = context.read<UserProvider>();
    userProvider.addListener(_onUserProviderChanged);
  }

  void _onUserProviderChanged() {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();

    if (userProvider.pendingAchievements.isNotEmpty) {
      final achievements = List<Achievement>.from(userProvider.pendingAchievements);
      userProvider.clearPendingAchievements();
      _showAchievementPopups(achievements);
    }

    if (userProvider.showLeaderboardEntryPopup) {
      final rank = userProvider.currentRank ?? 0;
      userProvider.clearLeaderboardEntryPopup();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          AchievementService.showLeaderboardEntryPopup(context, rank);
        }
      });
    }

    if (userProvider.showLeaderboardDropNotification) {
      userProvider.clearLeaderboardDropNotification();
      _sendLeaderboardDropNotification();
    }
  }

  void _showAchievementPopups(List<Achievement> achievements) async {
    final service = AchievementService();
    for (final achievement in achievements) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      AchievementService.showAchievementPopup(
        context,
        achievement,
        service.getRandomMotivationalQuote(),
      );
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _sendLeaderboardDropNotification() async {
    final notificationService = NotificationService();
    await notificationService.showInstantNotification(
      id: 100,
      title: "You're Losing Ground!",
      body: "You've dropped out of the top 50. Practice now to reclaim your spot on the leaderboard!",
      type: 'leaderboard_drop',
    );
  }

  @override
  void dispose() {
    try {
      context.read<UserProvider>().removeListener(_onUserProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined),
              activeIcon: Icon(Icons.leaderboard_rounded),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Statistics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
