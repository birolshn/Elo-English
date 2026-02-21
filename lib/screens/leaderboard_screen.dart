import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<UserProvider>().loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final leaderboard = userProvider.leaderboard;
    final isLoading = userProvider.isLeaderboardLoading;
    final currentUserCheck = context.watch<AuthProvider>().user;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            // Custom Header
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Haftalık Sıralama',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'En çok çalışanlar listesi',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : leaderboard.isEmpty
                      ? const Center(child: Text('Henüz sıralama verisi yok.'))
                      : RefreshIndicator(
                        onRefresh: () => userProvider.loadLeaderboard(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: leaderboard.length,
                          itemBuilder: (context, index) {
                            final entry = leaderboard[index];
                            final isMe = entry.userId == currentUserCheck?.uid;

                            return _buildLeaderboardItem(
                              context,
                              entry,
                              isMe,
                              currentUserCheck,
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    LeaderboardEntry entry,
    bool isMe,
    User? currentUser,
  ) {
    // Kullanıcı kendi girdisiyse, Firebase'deki güncel ismi kullan
    final displayName =
        isMe && currentUser?.displayName != null
            ? currentUser!.displayName!
            : entry.displayName;

    Color? rankColor;
    if (entry.rank == 1)
      rankColor = const Color(0xFFFFD700); // Gold
    else if (entry.rank == 2)
      rankColor = const Color(0xFFC0C0C0); // Silver
    else if (entry.rank == 3)
      rankColor = const Color(0xFFCD7F32); // Bronze

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            isMe
                ? Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                )
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: rankColor ?? Colors.grey.withOpacity(0.1),
            border:
                rankColor != null
                    ? Border.all(color: rankColor, width: 2)
                    : null,
          ),
          child:
              rankColor != null
                  ? Text(
                    '#${entry.rank}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  )
                  : Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
        ),
        title: Text(
          isMe ? '$displayName (Sen)' : displayName,
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
            color: isMe ? Theme.of(context).primaryColor : Colors.black87,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${entry.weeklyXp} XP',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
