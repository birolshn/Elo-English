import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/tts_service.dart';
import '../services/speech_error_helper.dart';
import '../services/api_service.dart';
import '../widgets/pronunciation_dialog.dart';

class ShadowingExercise {
  final String id;
  final String category;
  final String sentence;
  final String translation;
  final String focusTip;

  const ShadowingExercise({
    required this.id,
    required this.category,
    required this.sentence,
    required this.translation,
    required this.focusTip,
  });
}

class ShadowingScreen extends StatefulWidget {
  const ShadowingScreen({super.key});

  @override
  State<ShadowingScreen> createState() => _ShadowingScreenState();
}

class _ShadowingScreenState extends State<ShadowingScreen> {
  final TtsService _ttsService = TtsService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isPlaying = false;
  bool _isRecording = false;
  String _userSpokenText = '';
  int? _matchScore;
  int _currentIndex = 0;

  final List<ShadowingExercise> _exercises = const [
    ShadowingExercise(
      id: '1',
      category: 'Daily Fluency',
      sentence: "I'm really looking forward to catching up with you this weekend.",
      translation: "Bu hafta sonu seninle hasret gidermeyi gerçekten iple çekiyorum.",
      focusTip: "Focus on linking 'catching up' smoothly without a pause between words.",
    ),
    ShadowingExercise(
      id: '2',
      category: 'Business English',
      sentence: "Could you walk me through the key deliverables for the upcoming quarter?",
      translation: "Gelecek çeyrek için temel çıktıları bana adım adım özetleyebilir misiniz?",
      focusTip: "Pay attention to the soft /w/ sound in 'walk' and clear /d/ in 'deliverables'.",
    ),
    ShadowingExercise(
      id: '3',
      category: 'IELTS Band 8+ Expression',
      sentence: "Although there are valid arguments on both sides, the long-term benefits outweigh the drawbacks.",
      translation: "Her iki tarafta da geçerli argümanlar olsa da, uzun vadeli faydalar dezavantajlardan ağır basmaktadır.",
      focusTip: "Intonate with a slight rise on 'both sides', then a falling tone on 'drawbacks'.",
    ),
    ShadowingExercise(
      id: '4',
      category: 'Social Situations',
      sentence: "To be completely honest, that thought hadn't even crossed my mind.",
      translation: "Tamamen dürüst olmak gerekirse, bu düşünce aklımdan bile geçmemişti.",
      focusTip: "Blend 'hadn't even' together naturally.",
    ),
    ShadowingExercise(
      id: '5',
      category: 'Turkish Learner /θ/ Focus',
      sentence: "I think that thirty-three healthy athletes thoroughly enjoyed the marathon.",
      translation: "Bence otuz üç sağlıklı atlet maratondan son derece keyif aldı.",
      focusTip: "Place the tip of your tongue gently between your front teeth for 'th' (/θ/).",
    ),
  ];

  bool _speechReady = false;
  // Geç gelen STT callback'lerinin yanlış cümleyi puanlamaması için
  int _recordSession = 0;

  @override
  void initState() {
    super.initState();
    _ttsService.initialize();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize();
    } catch (e) {
      debugPrint('Shadowing STT init error: $e');
      _speechReady = false;
    }
  }

  @override
  void dispose() {
    _recordSession++;
    _speech.cancel();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _playSentence() async {
    if (_isRecording) await _cancelRecording();
    setState(() => _isPlaying = true);
    final target = _exercises[_currentIndex].sentence;
    // speak() ses bittiğinde tamamlanır
    await _ttsService.speak(target);
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _startRecording() async {
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition is not available. Please check microphone permissions.')),
          );
        }
        return;
      }
    }

    // Kullanıcı tekrar ederken model cümle çalmaya devam etmesin
    await _ttsService.stop();
    if (!mounted) return;

    final session = ++_recordSession;
    setState(() {
      _isRecording = true;
      _isPlaying = false;
      _userSpokenText = '';
      _matchScore = null;
    });

    // SpeechToText tekil (singleton); başka ekranın dinleyicilerini bu ekranınkilerle değiştir
    _speech.statusListener = (status) {
      if (session != _recordSession || !mounted || !_isRecording) return;
      if (status == stt.SpeechToText.doneStatus) _stopRecording();
    };
    _speech.errorListener = (error) {
      debugPrint('Shadowing STT error: ${error.errorMsg}');
      if (session != _recordSession || !mounted || !_isRecording) return;
      if (SpeechErrorHelper.isFatal(error.errorMsg) && _userSpokenText.trim().isEmpty) {
        _cancelRecording();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "Speech recognition isn't available on this device right now. "
                'On the iOS Simulator this is a known Apple issue, so please test on a real iPhone.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        return;
      }
      _stopRecording();
    };

    try {
      await _speech.listen(
        onResult: (result) {
          if (session != _recordSession || !mounted) return;
          setState(() {
            _userSpokenText = result.recognizedWords;
          });

          if (result.finalResult) {
            _stopRecording();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
        ),
      );
    } catch (e) {
      debugPrint('Shadowing STT listen error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return; // finalResult + done + kullanıcı dokunuşu aynı anda gelebilir
    final session = _recordSession;
    setState(() => _isRecording = false);
    await _speech.stop();
    if (!mounted || session != _recordSession) return;

    // Calculate match percentage using word matching
    final target = _exercises[_currentIndex].sentence;
    final score = _calculateSimilarity(target, _userSpokenText);

    setState(() {
      _matchScore = score;
    });
  }

  bool _isAnalyzing = false;

  Future<void> _showPhoneticAnalysis() async {
    final target = _exercises[_currentIndex].sentence;
    final spoken = _userSpokenText;
    setState(() => _isAnalyzing = true);
    final result = await ApiService().evaluatePronunciation(
      targetSentence: target,
      spokenText: spoken,
    );
    if (!mounted) return;
    setState(() => _isAnalyzing = false);
    PronunciationBottomSheet.show(context, result, target);
  }

  /// Kaydı puanlamadan iptal et (cümle değişince / dinletince)
  Future<void> _cancelRecording() async {
    _recordSession++;
    if (mounted) setState(() => _isRecording = false);
    await _speech.cancel();
  }

  int _calculateSimilarity(String target, String spoken) {
    if (spoken.trim().isEmpty) return 0;

    final targetWords = target.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));
    final spokenWords = spoken.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+'));

    int matches = 0;
    for (final word in targetWords) {
      if (spokenWords.contains(word)) {
        matches++;
      }
    }

    final ratio = matches / targetWords.length;
    return (ratio * 100).round().clamp(0, 100);
  }

  void _nextExercise() {
    if (_isRecording) _cancelRecording();
    _ttsService.stop();
    if (_currentIndex + 1 < _exercises.length) {
      setState(() {
        _currentIndex++;
        _userSpokenText = '';
        _matchScore = null;
      });
    }
  }

  void _prevExercise() {
    if (_isRecording) _cancelRecording();
    _ttsService.stop();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _userSpokenText = '';
        _matchScore = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _exercises[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Shadowing Mode (Gölgeleme)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // How it works card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Text('🗣️', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Listen to the native voice, then repeat with the same speed, tone, and rhythm to build natural speech habits.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Exercise Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Category & Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          current.category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Text(
                        '${_currentIndex + 1} / ${_exercises.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Target Sentence
                  Text(
                    '"${current.sentence}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Translation
                  Text(
                    current.translation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 20),

                  // Native Audio Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPlaying ? null : _playSentence,
                        icon: Icon(_isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded),
                        label: Text(_isPlaying ? 'Playing...' : 'Listen Native Voice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Focus Tip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            current.focusTip,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User Speaking Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Turn to Shadow',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 14),

                  // Big Mic Button
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                                .withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRecording ? 'Listening... Speak now!' : 'Tap mic to start repeating',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    ),
                  ),

                  // Recognized speech
                  if (_userSpokenText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'What you said: "$_userSpokenText"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                  ],

                  // Match Score Display
                  if (_matchScore != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _matchScore! >= 80 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _matchScore! >= 80 ? Icons.check_circle_rounded : Icons.info_rounded,
                            color: _matchScore! >= 80 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_matchScore% Match! ${_matchScore! >= 80 ? "Superb rhythm!" : "Try once more to improve!"}',
                            style: TextStyle(
                              color: _matchScore! >= 80 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_userSpokenText.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // Hedef cümle ile söyleneni karşılaştıran kelime bazlı analiz (Item 2.2)
                      TextButton.icon(
                        onPressed: _isAnalyzing ? null : _showPhoneticAnalysis,
                        icon: _isAnalyzing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.record_voice_over_rounded, size: 18),
                        label: const Text('Word-by-word phonetic analysis 🎯'),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bottom Navigation Next/Prev Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _currentIndex > 0 ? _prevExercise : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: _currentIndex + 1 < _exercises.length ? _nextExercise : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Next Sentence'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
