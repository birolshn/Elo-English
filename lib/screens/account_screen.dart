import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/user_provider.dart';
import 'privacy_policy_screen.dart';
import '../services/api_service.dart';
import '../widgets/premium_popup.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
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
              // Header
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
                child: Stack(
                  children: [
                    // Edit Profile Button (Top Right)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        onPressed: () => _showEditProfileDialog(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Edit Profile',
                      ),
                    ),
                    Column(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () => _showEditProfileDialog(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  user?.photoURL != null
                                      ? NetworkImage(user!.photoURL!)
                                      : null,
                              child:
                                  user?.photoURL == null
                                      ? Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: primaryColor,
                                      )
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name and Rank
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user?.displayName ?? 'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            // Weekly Rank Badge
                            if (context.watch<UserProvider>().currentRank !=
                                null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.emoji_events_rounded,
                                      color: Color(0xFFFFD700), // Gold
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '#${context.watch<UserProvider>().currentRank}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Email verification status
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                authProvider.isEmailVerified
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                authProvider.isEmailVerified
                                    ? Icons.verified_rounded
                                    : Icons.warning_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                authProvider.isEmailVerified
                                    ? 'Email Verified'
                                    : 'Email Not Verified',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                  children: [
                    // Account info card
                    _buildInfoCard(
                      context,
                      title: 'Account Information',
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          value: user?.displayName ?? 'Not specified',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.leaderboard_outlined,
                          label: 'Weekly Rank',
                          value:
                              context.watch<UserProvider>().currentRank != null
                                  ? '#${context.watch<UserProvider>().currentRank}'
                                  : ' - ',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user?.email ?? 'Not specified',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Registration Date',
                          value:
                              user?.metadata.creationTime != null
                                  ? _formatDate(user!.metadata.creationTime!)
                                  : 'Unknown',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),



                    // Premium Membership Card
                    _buildPremiumCard(context),

                    const SizedBox(height: 20),

                    // Privacy Policy Button
                    Container(
                      width: double.infinity,
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
                      child: ListTile(
                        leading: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Color(0xFF64748B),
                        ),
                        title: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Color(0xFFCBD5E1),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Danger zone
                    _buildInfoCard(
                      context,
                      title: 'Danger Zone',
                      titleColor: Colors.red,
                      children: [
                        const Text(
                          'When you delete your account, all your data will be permanently deleted. This action cannot be undone.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showDeleteAccountDialog(context),
                            icon: const Icon(Icons.delete_forever, size: 20),
                            label: const Text('Delete My Account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Log Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    final premiumProvider = context.watch<PremiumProvider>();
    final isPremium = premiumProvider.isPremium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            isPremium
                ? const LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                : null,
        color: isPremium ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isPremium
                    ? const Color(0xFF9333EA).withOpacity(0.3)
                    : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('👑', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Membership',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isPremium ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? 'Active - Unlimited practice available'
                          : 'Upgrade to premium for unlimited practice',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isPremium
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => showPremiumPopup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          if (isPremium) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showCancelSubscriptionDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.white.withOpacity(0.5)),
                ),
                child: const Text(
                  'Cancel Subscription',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text('Cancel Subscription'),
              ],
            ),
            content: const Text(
              'To cancel your premium subscription, manage your subscriptions in the iOS Settings app.\n\n'
              'You can cancel by navigating to Settings → Apple ID → Subscriptions.\n\n'
              '• You can continue using your premium benefits until the end of the current period',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    Color? titleColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: titleColor ?? const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Log Out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<AuthProvider>().signOut();
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Delete Account'),
              ],
            ),
            content: const Text(
              'Your account will be permanently deleted.\n\nThis action cannot be undone. All your data will be cleared.\n\nDo you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final authProvider = context.read<AuthProvider>();
                  final success = await authProvider.deleteAccount();
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          authProvider.errorMessage ??
                              'Deleting your account will permanently remove all your data. This action cannot be undone.',
                        ),
                        backgroundColor: Colors.red.shade600,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Yes, Delete',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    final nameController = TextEditingController(text: user?.displayName);
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo Edit UI
                GestureDetector(
                  onTap: () async {
                    try {
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        requestFullMetadata: false,
                      );

                      if (image != null && context.mounted) {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Uploading photo...'),
                            duration: Duration(seconds: 2),
                          ),
                        );

                        // Upload to backend
                        final apiService = ApiService();
                        final photoUrl = await apiService.uploadAvatar(
                          image.path,
                        );

                        // Update Auth Profile
                        if (context.mounted) {
                          final success = await authProvider.updateProfile(
                            photoURL: photoUrl,
                          );

                          if (success && context.mounted) {
                            Navigator.pop(context); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile photo updated!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Ensure UI updates by reloading user? AuthProvider does it.
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  authProvider.errorMessage ??
                                      'An error occurred',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('Error picking/uploading image: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                        child:
                            user?.photoURL == null
                                ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey,
                                )
                                : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty && newName != user?.displayName) {
                    Navigator.pop(context);
                    final success = await authProvider.updateProfile(
                      displayName: newName,
                    );
                    if (context.mounted) {
                      if (success) {
                        // Backend ile senkronize et (Leaderboard için)
                        context.read<UserProvider>().updateDisplayName(newName);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authProvider.errorMessage ?? 'An error occurred',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Kaydet',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }
}
