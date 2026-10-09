import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/scenario_provider.dart';
import '../services/api_service.dart';

class CustomScenarioDialog extends StatefulWidget {
  const CustomScenarioDialog({super.key});

  /// Oluşturulan senaryoyu döndürür; başlatma (kredi kontrolü dahil) çağırana aittir.
  static Future<Scenario?> show(BuildContext context) {
    return showModalBottomSheet<Scenario>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CustomScenarioDialog(),
    );
  }

  @override
  State<CustomScenarioDialog> createState() => _CustomScenarioDialogState();
}

class _CustomScenarioDialogState extends State<CustomScenarioDialog> {
  // Senaryolar ekranındaki "Create with AI" butonuyla aynı renk
  static const Color _accent = Color(0xFF8B5CF6);

  final TextEditingController _promptController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _selectedDifficulty = 'intermediate';

  final List<String> _quickIdeas = [
    'Negotiate rent increase with landlord',
    'Doctor visit describing back pain in London',
    'Technical job interview for software developer',
    'Reporting lost luggage at baggage claim',
    'Asking for a refund at an electronics store',
  ];

  Future<void> _generateScenario() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final scenario = await _apiService.createCustomScenario(
        userPrompt: text,
        userLevel: _selectedDifficulty,
      );

      if (!mounted) return;

      // Add to scenario provider
      await context.read<ScenarioProvider>().addCustomScenario(scenario);
      if (!mounted) return;

      // Senaryoyu çağırana döndür: liste ekranı günlük kredi / premium
      // kontrolünü yapıp konuşmayı başlatır (ücretsiz limit atlanmasın).
      Navigator.pop(context, scenario);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate scenario: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        // Alt boşluk: iPhone ana ekran çubuğunun üstünde kalsın
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + (bottomInset > 0 ? 0 : MediaQuery.of(context).padding.bottom),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Custom Scenario',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Practice any real-world situation with AI',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Text Field
              TextField(
                controller: _promptController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'What situation do you want to practice?\ne.g., "I want to negotiate a promotion with my boss."',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _accent, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Quick Idea Chips
              const Text(
                'Quick ideas:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickIdeas.map((idea) {
                  return ActionChip(
                    label: Text(
                      idea,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      _promptController.text = idea;
                      _promptController.selection = TextSelection.collapsed(offset: idea.length);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Difficulty Selector
              // Etiket + 3 çip tek satıra sığmıyordu (seçili çipin onay işaretiyle
              // taşma oluşuyordu); etiket üstte, çipler eşit genişlikte
              const Text(
                'Difficulty:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['beginner', 'intermediate', 'advanced'].map((lvl) {
                  final isSel = _selectedDifficulty == lvl;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: lvl == 'advanced' ? 0 : 8),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            lvl.capitalize(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        showCheckmark: false,
                        selected: isSel,
                        selectedColor: _accent,
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide(color: isSel ? _accent : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedDifficulty = lvl);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Generate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _generateScenario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Generating Scenario with AI...',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 22),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Start Custom Roleplay',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
