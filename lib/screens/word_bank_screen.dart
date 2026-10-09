import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/word_bank_service.dart';
import '../services/tts_service.dart';

class WordBankScreen extends StatefulWidget {
  const WordBankScreen({super.key});

  @override
  State<WordBankScreen> createState() => _WordBankScreenState();
}

class _WordBankScreenState extends State<WordBankScreen> {
  final WordBankService _wordBankService = WordBankService();
  final TtsService _ttsService = TtsService();

  List<SavedWord> _words = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    final list = await _wordBankService.getAllWords();
    if (mounted) {
      setState(() {
        _words = list;
        _isLoading = false;
      });
    }
  }

  void _startFlashcards() {
    // Aralıklı tekrar: yalnızca zamanı gelen kelimeler çalışılır
    final dueWords = _words.where((w) => w.isDueForReview).toList();
    if (dueWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words are due for review right now. Come back later! ⏰')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashcardsScreen(
          words: dueWords,
          onComplete: () => _loadWords(),
        ),
      ),
    );
  }

  void _showAddWordDialog() {
    final wordController = TextEditingController();
    final meaningController = TextEditingController();
    final exampleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Word Bank'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wordController,
              decoration: const InputDecoration(labelText: 'Word / Phrase (e.g. Eloquent)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: meaningController,
              decoration: const InputDecoration(labelText: 'Meaning / Turkish Translation'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: exampleController,
              decoration: const InputDecoration(labelText: 'Example Sentence'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (wordController.text.trim().isNotEmpty) {
                await _wordBankService.saveWord(
                  word: wordController.text.trim(),
                  meaning: meaningController.text.trim(),
                  exampleSentence: exampleController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  _loadWords();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dueCount = _words.where((w) => w.isDueForReview).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Vocabulary Bank (Kelime Defterim)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF2563EB), size: 28),
            onPressed: _showAddWordDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Flashcards banner card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spaced Repetition (SRS)',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$dueCount Words Due for Review',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total ${_words.length} saved words in bank',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _words.isEmpty ? null : _startFlashcards,
                        icon: const Icon(Icons.style_rounded, size: 18),
                        label: const Text('Review Cards'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D9488),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // Words List
                Expanded(
                  child: _words.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(Icons.bookmark_add_rounded, color: Color(0xFF0D9488), size: 48),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your Word Bank is Empty',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap the Star icon during conversations to save words here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _words.length,
                          itemBuilder: (context, index) {
                            final w = _words[index];
                            return _buildWordCard(w);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildWordCard(SavedWord item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
              // Kaydedilen öneriler uzun cümleler olabilir; taşmasın
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.word,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0D9488), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _ttsService.speak(item.word),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.isDueForReview ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.isDueForReview ? 'Due for review' : 'Next: in ${item.intervalDays}d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.isDueForReview ? const Color(0xFFD97706) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await _wordBankService.deleteWord(item.id);
                      _loadWords();
                    },
                  ),
                ],
              ),
            ],
          ),
          if (item.meaning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.meaning,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0D9488),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.exampleSentence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${item.exampleSentence}"',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spaced Repetition Flashcards Review Mode
class FlashcardsScreen extends StatefulWidget {
  final List<SavedWord> words;
  final VoidCallback onComplete;

  const FlashcardsScreen({
    super.key,
    required this.words,
    required this.onComplete,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final WordBankService _wordBankService = WordBankService();
  final TtsService _ttsService = TtsService();

  int _currentIndex = 0;
  bool _isAnswerRevealed = false;
  bool _isRating = false;

  /// Buton etiketi için bir sonraki tekrar aralığı (ör. "Good\n(3d)")
  String _ratingLabel(String title, String rating) {
    final days = WordBankService.computeNextReview(widget.words[_currentIndex], rating).interval;
    return '$title\n(${days}d)';
  }

  void _rate(String rating) async {
    // Çift dokunuşta aynı kart iki kez puanlanmasın
    if (_isRating) return;
    _isRating = true;
    final current = widget.words[_currentIndex];
    await _wordBankService.reviewWord(current.id, rating);
    _isRating = false;
    if (!mounted) return;

    if (_currentIndex + 1 < widget.words.length) {
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false;
      });
    } else {
      widget.onComplete();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Flashcards Session Complete!'),
        content: const Text('You successfully reviewed your saved words. Aralıklı tekrar sayesinde hafızanız güçlendi!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back to Word Bank'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.words[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Reviewing Cards (${_currentIndex + 1}/${widget.words.length})'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Flashcard
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isAnswerRevealed) {
                    setState(() => _isAnswerRevealed = true);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        current.word,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 30, color: Color(0xFF0D9488)),
                        onPressed: () => _ttsService.speak(current.word),
                      ),
                      const SizedBox(height: 24),
                      if (!_isAnswerRevealed) ...[
                        const Text(
                          'Tap to reveal definition',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                      ] else ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          current.meaning.isNotEmpty ? current.meaning : 'Definition in English practice',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        if (current.exampleSentence.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            '"${current.exampleSentence}"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Rating Buttons (SM-2)
            if (_isAnswerRevealed)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRatingButton(_ratingLabel('Again', 'again'), const Color(0xFFEF4444), () => _rate('again')),
                  _buildRatingButton(_ratingLabel('Hard', 'hard'), const Color(0xFFF59E0B), () => _rate('hard')),
                  _buildRatingButton(_ratingLabel('Good', 'good'), const Color(0xFF10B981), () => _rate('good')),
                  _buildRatingButton(_ratingLabel('Easy', 'easy'), const Color(0xFF2563EB), () => _rate('easy')),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _isAnswerRevealed = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Show Meaning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color, width: 1.5),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
