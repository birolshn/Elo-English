import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/premium_provider.dart';
import '../widgets/premium_popup.dart';

/// Onboarding sonunda gösterilen ücretsiz deneme teklifi.
/// Deneme süresi mağazadaki ürün tanımından gelir; tanımlı değilse ekran
/// deneme vaat etmez ve normal yıllık satın alma olarak çalışır.
class TrialOfferScreen extends StatefulWidget {
  const TrialOfferScreen({super.key});

  /// Teklifi tam ekran açar; satın alma / deneme başladıysa true döner
  static Future<bool> show(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const TrialOfferScreen()),
    );
    return result ?? false;
  }

  @override
  State<TrialOfferScreen> createState() => _TrialOfferScreenState();
}

class _TrialOfferScreenState extends State<TrialOfferScreen> {
  static const Color _accent = Color(0xFF9333EA);
  static const Color _dark = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);

  bool _isPurchasing = false;

  Future<void> _startTrial(PremiumProvider premium) async {
    setState(() => _isPurchasing = true);
    final success = await premium.purchaseSelectedPlan('yearly');
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(premium.hasYearlyTrial
              ? '🎉 Your free trial has started!'
              : '🎉 Premium membership activated!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _restore(PremiumProvider premium) async {
    setState(() => _isPurchasing = true);
    final restored = await premium.restorePurchases();
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    if (restored) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchases found.')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    final trialDays = premium.yearlyTrialDays;
    final hasTrial = trialDays != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Continue with free plan',
                icon: const Icon(Icons.close_rounded, color: _muted),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 38),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      hasTrial ? 'Try Premium free for $trialDays days' : 'Unlock Elo English Premium',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _dark, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reach your speaking goal faster with unlimited AI practice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: _muted),
                    ),
                    const SizedBox(height: 24),
                    _benefit(Icons.all_inclusive_rounded, 'Unlimited conversations', 'No daily scenario limit, including open-topic chats'),
                    _benefit(Icons.phone_in_talk_rounded, 'Unlimited AI phone calls', 'Practice hands-free, as long as you like'),
                    _benefit(Icons.school_rounded, 'IELTS & TOEFL mock tests', 'Full criteria breakdown, next-band tips & PDF report'),
                    _benefit(Icons.auto_awesome_rounded, 'Unlimited custom AI scenarios', 'Rehearse any real-life situation you need'),
                    if (hasTrial) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'How your free trial works',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _dark),
                      ),
                      const SizedBox(height: 12),
                      _timelineStep(Icons.lock_open_rounded, 'Today', 'Get full access to every Premium feature.', isFirst: true),
                      _timelineStep(
                        Icons.notifications_active_rounded,
                        'Day ${trialDays > 2 ? trialDays - 2 : 1}',
                        "We'll remind you before your trial ends.",
                      ),
                      _timelineStep(
                        Icons.star_rounded,
                        'Day $trialDays',
                        'Your subscription starts at ${premium.yearlyPrice}/year. Cancel anytime before.',
                        isLast: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPurchasing || premium.isLoading ? null : () => _startTrial(premium),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _accent.withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isPurchasing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              hasTrial ? 'Start $trialDays-Day Free Trial' : 'Get Premium - ${premium.yearlyPrice}/year',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasTrial
                        ? 'Free for $trialDays days, then ${premium.yearlyPrice}/year. Cancel anytime.'
                        : 'Billed yearly. Cancel anytime.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  // Dar ekranda / büyük yazıda alt satıra geçebilsin
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isPurchasing
                            ? null
                            : () => showPremiumPopup(
                                  context,
                                  onPurchaseSuccess: () => Navigator.of(context).pop(true),
                                ),
                        child: const Text('See all plans', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
                      ),
                      const Text('·', style: TextStyle(color: _muted)),
                      TextButton(
                        onPressed: _isPurchasing ? null : () => _restore(premium),
                        child: const Text('Restore', style: TextStyle(color: _muted)),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Continue with free plan',
                      style: TextStyle(color: _muted, fontSize: 14, decoration: TextDecoration.underline),
                    ),
                  ),
                  Text(
                    '${hasTrial ? 'The free trial converts to a paid subscription unless cancelled at least 24 hours before it ends. ' : ''}'
                    'The subscription renews automatically unless auto-renew is turned off at least 24 hours before the end of the current period. '
                    'Manage or cancel anytime in your account settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _openUrl('https://birolshn.github.io/Elo-English/privacy_policy.html'),
                        child: Text('Privacy Policy',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, decoration: TextDecoration.underline)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ),
                      GestureDetector(
                        onTap: () => _openUrl('https://birolshn.github.io/Elo-English/terms_of_use.html'),
                        child: Text('Terms of Use (EULA)',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _dark)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineStep(IconData icon, String title, String text, {bool isFirst = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 4,
                  color: isFirst ? Colors.transparent : _accent.withValues(alpha: 0.3),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isFirst ? _accent : _accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: isFirst ? Colors.white : _accent),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : _accent.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(fontSize: 12, color: _muted, height: 1.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
