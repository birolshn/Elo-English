import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
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
                      'Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final url = Uri.parse(
                        'https://elo-english-api.onrender.com/privacy',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.language, color: Colors.white),
                    tooltip: 'View Online',
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last updated: April 8, 2026',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      '1. Data Collection',
                      'Elo English collects the following data:\n• Account Information: Email address and display name (via Firebase Authentication)\n• Usage Data: Conversation history, progress statistics, completed scenarios\n• Audio Data: Microphone access during speaking practice (only during active conversations)\n• Profile Photo: Optionally uploaded profile image\n• Purchase Data: Subscription status (via RevenueCat)',
                    ),
                    _buildSection(
                      '2. Data Usage',
                      'Collected data is used for: account management, personalizing the English practice experience, progress tracking and leaderboards, subscription management, and improving app performance.',
                    ),
                    _buildSection(
                      '3. Third-Party Services',
                      'Our app uses Firebase (Google), Google Gemini AI, RevenueCat, and Apple App Store services.',
                    ),
                    _buildSection(
                      '4. Data Security',
                      'Your data is protected with HTTPS encryption. Firebase authentication follows industry-standard security practices.',
                    ),
                    _buildSection(
                      '5. Data Retention and Deletion',
                      'Your data is retained as long as your account is active. You can delete your account from within the app, which will permanently delete all your data.',
                    ),
                    _buildSection(
                      '6. Children\'s Privacy',
                      'This app is not intended for children under 13 and does not knowingly collect personal information from children under 13.',
                    ),
                    _buildSection(
                      '7. Changes',
                      'This privacy policy may be updated from time to time. Changes will be posted to this page.',
                    ),
                    _buildSection(
                      '8. Contact',
                      'For questions about our privacy policy, contact: birolsahin037@gmail.com',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
