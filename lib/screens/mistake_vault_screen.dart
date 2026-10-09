import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/mistake_vault_service.dart';

class MistakeVaultScreen extends StatefulWidget {
  const MistakeVaultScreen({super.key});

  @override
  State<MistakeVaultScreen> createState() => _MistakeVaultScreenState();
}

class _MistakeVaultScreenState extends State<MistakeVaultScreen> {
  final MistakeVaultService _vaultService = MistakeVaultService();
  List<MistakeItem> _mistakes = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'needs_practice', 'mastered'

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    setState(() => _isLoading = true);
    final list = await _vaultService.getMistakes();
    if (mounted) {
      setState(() {
        _mistakes = list;
        _isLoading = false;
      });
    }
  }

  List<MistakeItem> get _filteredMistakes {
    if (_selectedFilter == 'needs_practice') {
      return _mistakes.where((m) => !m.isMastered).toList();
    } else if (_selectedFilter == 'mastered') {
      return _mistakes.where((m) => m.isMastered).toList();
    }
    return _mistakes;
  }

  void _startPracticeQuiz() {
    final unmastered = _mistakes.where((m) => !m.isMastered).toList();
    if (unmastered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All mistakes have been mastered! Great job! 🎉')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MistakePracticeQuizScreen(
          mistakes: unmastered,
          onComplete: () => _loadMistakes(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masteredCount = _mistakes.where((m) => m.isMastered).length;
    final totalCount = _mistakes.length;
    final progressPercent = totalCount > 0 ? masteredCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mistake Vault (Hata Defterim)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          if (_mistakes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF64748B)),
              tooltip: 'Clear All',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Mistake Vault?'),
                    content: const Text('Are you sure you want to delete all saved grammar mistakes?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _vaultService.clearAll();
                  _loadMistakes();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Progress & Practice Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mistake Mastery',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$masteredCount of $totalCount Corrected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _mistakes.isEmpty ? null : _startPracticeQuiz,
                            icon: const Icon(Icons.flash_on_rounded, size: 18),
                            label: const Text('Practice Mistakes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All (${_mistakes.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Needs Practice (${_mistakes.where((m) => !m.isMastered).length})', 'needs_practice'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Mastered ($masteredCount)', 'mastered'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Mistakes List
                Expanded(
                  child: _filteredMistakes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2563EB), size: 48),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No mistakes here!',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Grammar feedback from your chats appears here automatically.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredMistakes.length,
                          itemBuilder: (context, index) {
                            final item = _filteredMistakes[index];
                            return _buildMistakeCard(item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildMistakeCard(MistakeItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isMastered ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.scenarioTitle,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
              Row(
                children: [
                  if (item.isMastered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 14),
                          SizedBox(width: 4),
                          Text('Mastered', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await _vaultService.deleteMistake(item.id);
                      _loadMistakes();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // You said
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('❌ ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  'You said: "${item.originalText}"',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Correct version
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✅ ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  'Better: "${item.correctedText}"',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (item.explanation.isNotEmpty && item.explanation != item.correctedText) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 ${item.explanation}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive Mini-Quiz to Practice Past Mistakes
class MistakePracticeQuizScreen extends StatefulWidget {
  final List<MistakeItem> mistakes;
  final VoidCallback onComplete;

  const MistakePracticeQuizScreen({
    super.key,
    required this.mistakes,
    required this.onComplete,
  });

  @override
  State<MistakePracticeQuizScreen> createState() => _MistakePracticeQuizScreenState();
}

class _MistakePracticeQuizScreenState extends State<MistakePracticeQuizScreen> {
  final MistakeVaultService _vaultService = MistakeVaultService();
  int _currentIndex = 0;
  bool? _selectedIsCorrect;
  late List<String> _shuffledOptions;

  @override
  void initState() {
    super.initState();
    _setupCurrentQuestion();
  }

  void _setupCurrentQuestion() {
    _selectedIsCorrect = null;
    final item = widget.mistakes[_currentIndex];
    _shuffledOptions = [item.correctedText, item.originalText]..shuffle();
  }

  void _checkAnswer(String option) async {
    final item = widget.mistakes[_currentIndex];
    final isCorrect = option == item.correctedText;

    setState(() {
      _selectedIsCorrect = isCorrect;
    });

    if (isCorrect) {
      await _vaultService.markAsMastered(item.id);
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentIndex + 1 < widget.mistakes.length) {
        setState(() {
          _currentIndex++;
          _setupCurrentQuestion();
        });
      } else {
        widget.onComplete();
        _showSuccessDialog();
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Practice Completed!'),
        content: const Text('You successfully reviewed and mastered your grammar mistakes! Keep it up!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.mistakes[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Practice Quiz (${_currentIndex + 1}/${widget.mistakes.length})'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the grammatically correct sentence:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 24),

            ..._shuffledOptions.map((opt) {
              final isTarget = opt == item.correctedText;
              Color borderColor = const Color(0xFFE2E8F0);
              Color bgColor = Colors.white;

              if (_selectedIsCorrect != null) {
                if (isTarget) {
                  borderColor = const Color(0xFF10B981);
                  bgColor = const Color(0xFFECFDF5);
                } else if (_selectedIsCorrect == false) {
                  borderColor = const Color(0xFFEF4444);
                  bgColor = const Color(0xFFFEF2F2);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: _selectedIsCorrect == null ? () => _checkAnswer(opt) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Text(
                      opt,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              );
            }),

            const Spacer(),

            if (_selectedIsCorrect != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedIsCorrect! ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedIsCorrect! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: _selectedIsCorrect! ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedIsCorrect! ? 'Perfect! Marked as mastered.' : 'Not quite. The correct one is marked in green.',
                        style: TextStyle(
                          color: _selectedIsCorrect! ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
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
}
