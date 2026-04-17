import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/premium_provider.dart';

class PremiumPopup extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onPurchaseSuccess;
  final String? triggerContext;

  const PremiumPopup({
    super.key,
    this.onClose,
    this.onPurchaseSuccess,
    this.triggerContext,
  });

  @override
  State<PremiumPopup> createState() => _PremiumPopupState();
}

class _PremiumPopupState extends State<PremiumPopup> {
  String _selectedPlan = 'yearly';

  @override
  Widget build(BuildContext context) {
    final premiumProvider = context.watch<PremiumProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable content area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gradient Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.triggerContext == 'daily_limit'
                                ? '⏰'
                                : (widget.triggerContext == 'ielts' ? '🎓' : '👑'),
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.triggerContext == 'daily_limit'
                                ? 'Daily Limit Reached!'
                                : (widget.triggerContext == 'ielts'
                                    ? 'IELTS Speaking is Premium'
                                    : 'Premium Membership'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.triggerContext == 'daily_limit'
                                ? 'Daily free limit reached! Go Premium for unlimited practice.'
                                : (widget.triggerContext == 'ielts'
                                    ? 'Practice with AI-powered mock tests and get feedback.'
                                    : 'Unlimited English practice opportunities!'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Benefits
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Column(
                        children: [
                          _buildBenefitItem(
                            icon: Icons.auto_awesome,
                            title: 'IELTS Simulator & Feedback',
                            description: 'Full mock tests with AI score feedback',
                          ),
                          const SizedBox(height: 8),
                          _buildBenefitItem(
                            icon: Icons.all_inclusive,
                            title: 'Unlimited Practice',
                            description: 'No daily limits or time restrictions',
                          ),
                          const SizedBox(height: 8),
                          _buildBenefitItem(
                            icon: Icons.star,
                            title: 'Advanced Scenarios',
                            description: 'Access to professional & academic content',
                          ),
                        ],
                      ),
                    ),

                    // Price & Plan Selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            'Choose a plan:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          // 2x2 Grid for 4 plans
                          Row(
                            children: [
                              _buildPlanOption(
                                title: '1 Month',
                                price: premiumProvider.monthlyPrice,
                                subtitle: 'Flexible',
                                planId: 'monthly',
                              ),
                              const SizedBox(width: 12),
                              _buildPlanOption(
                                title: '3 Months',
                                price: premiumProvider.threeMonthPrice,
                                subtitle: 'Popular',
                                planId: '3month',
                                isMostPopular: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildPlanOption(
                                title: '6 Months',
                                price: premiumProvider.sixMonthPrice,
                                subtitle: 'Advantageous',
                                planId: '6month',
                              ),
                              const SizedBox(width: 12),
                              _buildPlanOption(
                                title: '12 Months',
                                price: premiumProvider.yearlyPrice,
                                subtitle: '${premiumProvider.yearlyMonthlyEquivalent}/month',
                                planId: 'yearly',
                                isBestValue: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Fixed CTA at the bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: premiumProvider.isLoading
                          ? null
                          : () async {
                              final success = await premiumProvider.purchaseSelectedPlan(_selectedPlan);
                              if (success && mounted) {
                                widget.onPurchaseSuccess?.call();
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🎉 Premium membership activated!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9333EA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: premiumProvider.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              'Get Premium - ${_getSelectedPlanPrice(premiumProvider)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onClose?.call();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF9333EA), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String price,
    required String subtitle,
    required String planId,
    bool isBestValue = false,
    bool isMostPopular = false,
  }) {
    final isSelected = _selectedPlan == planId;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPlan = planId;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF9333EA) : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              if (isBestValue || isMostPopular)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isBestValue ? const Color(0xFF9333EA) : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBestValue ? 'BEST VALUE' : 'MOST POPULAR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF9333EA) : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSelectedPlanPrice(PremiumProvider premiumProvider) {
    switch (_selectedPlan) {
      case 'monthly':
        return premiumProvider.monthlyPrice;
      case '3month':
        return premiumProvider.threeMonthPrice;
      case '6month':
        return premiumProvider.sixMonthPrice;
      case 'yearly':
        return premiumProvider.yearlyPrice;
      default:
        return premiumProvider.yearlyPrice;
    }
  }
}

/// Premium popup'ı göster
void showPremiumPopup(
  BuildContext context, {
  VoidCallback? onPurchaseSuccess,
  String? triggerContext,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder:
        (context) => PremiumPopup(
          onPurchaseSuccess: onPurchaseSuccess,
          triggerContext: triggerContext,
        ),
  );
}

/// Konuşma tamamlandı dialog'u
void showConversationCompletedDialog(
  BuildContext context, {
  required bool isPremium,
  required VoidCallback onContinue,
  required VoidCallback onExit,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text(
                  'Conversation Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The time limit for this scenario has been reached.\nYou had a great practice session!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                if (isPremium) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onContinue();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue (+5 min)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Premium değilse önce premium popup, sonra çıkış butonu göster
                if (!isPremium) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        // Premium popup göster
                        showPremiumPopup(
                          context,
                          onPurchaseSuccess: () {
                            // Premium alındıysa devam et
                            onContinue();
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9333EA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('👑 ', style: TextStyle(fontSize: 16)),
                          Text(
                            'Upgrade to Premium',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onExit();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      isPremium ? 'End Conversation' : 'Exit',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}
