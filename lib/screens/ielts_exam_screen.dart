import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/speech_error_helper.dart';
import '../services/tts_service.dart';
import '../services/pdf_report_service.dart';
import '../providers/ielts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../services/premium_gate_service.dart';
import '../widgets/premium_popup.dart';
import 'dart:ui' show ImageFilter;
import '../models/models.dart';

class IeltsExamScreen extends StatefulWidget {
  const IeltsExamScreen({super.key});

  @override
  State<IeltsExamScreen> createState() => _IeltsExamScreenState();
}

class _IeltsExamScreenState extends State<IeltsExamScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();

  bool _isListening = false;
  bool _speechEnabled = false;
  bool _pendingAutoSend = false;
  IeltsProvider? _ieltsProvider;
  bool _isKeyboardMode = false;
  bool _shouldBeListening = false;

  // Pulsating animation for mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
    _initTts();
    _refreshFreeExamStatus();
  }

  final PremiumGateService _gate = PremiumGateService();
  // Ücretsiz kullanıcının bir sonraki ücretsiz sınav zamanı (null = hakkı var)
  DateTime? _nextFreeExamAt;
  bool _freeExamStatusLoaded = false;

  Future<void> _refreshFreeExamStatus() async {
    final next = await _gate.nextFreeExamAt();
    if (!mounted) return;
    setState(() {
      _nextFreeExamAt = next;
      _freeExamStatusLoaded = true;
    });
  }

  int _lastSpokenMessageCount = 0;
  bool _scrolledToResults = false;

  /// IELTS sınavında AI tarafından eklenen yeni mesajları otomatik seslendir
  void _checkAndSpeakLatestAssistantMessage(IeltsProvider provider) {
    if (!provider.isExamActive || provider.messages.isEmpty) {
      _lastSpokenMessageCount = provider.messages.length;
      return;
    }

    if (provider.messages.length > _lastSpokenMessageCount) {
      // Aynı anda eklenen mesajları (ör. geçiş metni + ilk cümle) sırayla oku
      final newAssistantMessages = provider.messages
          .sublist(_lastSpokenMessageCount)
          .where((m) => m.role == 'assistant')
          .map((m) => m.content)
          .toList();
      _lastSpokenMessageCount = provider.messages.length;
      if (newAssistantMessages.isNotEmpty) {
        _ttsService.stop().then((_) {
          for (final text in newAssistantMessages) {
            _ttsService.enqueue(text);
          }
        });
      }
    } else if (provider.messages.length < _lastSpokenMessageCount) {
      _lastSpokenMessageCount = provider.messages.length;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ieltsProvider = context.read<IeltsProvider>();
  }

  Future<void> _initSpeech() async {
    // Önceki session'ı temizle (conversation screen'den kalma olabilir)
    await _speech.cancel();

    _speechEnabled = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    _attachSpeechListeners();
    debugPrint('🎤 IELTS Speech initialized: $_speechEnabled');
    if (mounted) setState(() {});
  }

  /// SpeechToText tekil (singleton) ve initialize() ikinci kez çağrıldığında
  /// dinleyicileri güncellemiyor; diğer ekranlar kendi dinleyicilerini bağlamış
  /// olabileceği için her listen() öncesi bu ekranınkiler yeniden bağlanır.
  void _attachSpeechListeners() {
    _speech.statusListener = _onSpeechStatus;
    _speech.errorListener = _onSpeechError;
  }

  // Tanıma motoru açılıp hemen kapanıyorsa (sonuçsuz) sonsuz yeniden başlatmayı önle
  DateTime? _listenStartedAt;
  int _rapidFailures = 0;

  Future<void> _onSpeechStatus(String status) async {
    debugPrint('🎤 IELTS Speech status: $status');
    if (status == 'done' && mounted) {
      if (_shouldBeListening) {
        final startedAt = _listenStartedAt;
        if (startedAt != null &&
            DateTime.now().difference(startedAt) < const Duration(seconds: 1)) {
          _rapidFailures++;
          if (_rapidFailures >= 3) {
            _handleSpeechUnavailable();
            return;
          }
        }
        // Auto-restart if we are supposed to be listening
        await Future.delayed(const Duration(milliseconds: 50));
        if (_shouldBeListening && mounted) {
          _startListening();
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isListening = false);
      }
    } else if (status == 'listening' && mounted) {
      _pulseController.repeat(reverse: true);
      setState(() => _isListening = true);
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint('❌ IELTS Speech error: $error');
    if (!mounted) return;
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);
    final errorMsg = error is SpeechRecognitionError ? error.errorMsg : '$error';
    if (SpeechErrorHelper.isFatal(errorMsg)) _handleSpeechUnavailable();
  }

  /// Tanıma motoru çalışmıyor: yeniden denemeyi bırak, kullanıcıya klavyeyi öner
  void _handleSpeechUnavailable() {
    _shouldBeListening = false;
    _pendingAutoSend = false;
    _rapidFailures = 0;
    _speech.cancel();
    if (!mounted) return;
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(SpeechErrorHelper.unavailableMessage),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Type instead',
          onPressed: () {
            if (mounted) setState(() => _isKeyboardMode = true);
          },
        ),
      ),
    );
  }

  /// Premium: sınırsız. Ücretsiz: haftada 1 deneme sınavı, sonrası paywall.
  Future<void> _startExam(BuildContext context) async {
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (!isPremium) {
      if (!await _gate.canStartFreeExam()) {
        if (!context.mounted) return;
        showPremiumPopup(
          context,
          triggerContext: 'ielts',
          onPurchaseSuccess: () {
            if (mounted) _beginExam(this.context);
          },
        );
        return;
      }
      await _gate.markFreeExamUsed();
      await _refreshFreeExamStatus();
      if (!context.mounted) return;
    }
    _beginExam(context);
  }

  void _beginExam(BuildContext context) {
    final provider = context.read<IeltsProvider>();
    // IELTS İngiliz, TOEFL Amerikan aksanıyla okunsun
    _ttsService.setLanguage(
      provider.selectedExamType == AcademicExamType.toefl ? 'en-US' : 'en-GB',
    );
    _lastSpokenMessageCount = 0;
    String? candidateName;
    try {
      candidateName = context.read<AuthProvider>().user?.displayName;
    } catch (_) {
      // Giriş bilgisi yoksa rapor "Student" adıyla oluşturulur
    }
    provider.startExam(candidateName: candidateName);
  }

  Future<void> _initTts() async {
    await _ttsService.initialize(
      language: 'en-GB',
    ); // British English for IELTS
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ListView tembel ölçtüğü için ilk hedef, uzun son öğenin (sonuç kartı)
      // sonuna varmayabilir; kaydırma bitince bir kez daha sona git
      for (var pass = 0; pass < 2; pass++) {
        if (!mounted || !_scrollController.hasClients) return;
        final target = _scrollController.position.maxScrollExtent;
        if ((_scrollController.offset - target).abs() < 1) return;
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      debugPrint('❌ IELTS Speech not enabled, trying to reinitialize...');
      await _initSpeech();
      if (!_speechEnabled) return;
    }

    _shouldBeListening = true;
    _listenStartedAt = DateTime.now();
    _attachSpeechListeners();
    // Sınav görevlisi konuşurken mikrofon açılırsa sesi kes (yankı olmasın)
    _ttsService.stop();
    final existingText = _messageController.text.trim();

    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) _rapidFailures = 0;
        debugPrint(
          '🎤 IELTS Recognized: ${result.recognizedWords} (final: ${result.finalResult})',
        );
        setState(() {
          if (existingText.isNotEmpty) {
            _messageController.text = '$existingText ${result.recognizedWords}';
          } else {
            _messageController.text = result.recognizedWords;
          }
        });
        // Auto-send: finalResult geldiğinde ve pendingAutoSend true ise gönder
        if (result.finalResult && _pendingAutoSend && mounted) {
          _pendingAutoSend = false;
          if (_messageController.text.trim().isNotEmpty) {
            _sendMessage();
          }
        }
      },
      localeId: 'en_US',
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 60),
      listenMode: stt.ListenMode.dictation,
    );

    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    _shouldBeListening = false;
    _pendingAutoSend = true;
    await _speech.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);
    // Fallback: stop sonrası metin varsa ve finalResult gelmezse de gönder
    await Future.delayed(const Duration(milliseconds: 500));
    if (_pendingAutoSend &&
        mounted &&
        _messageController.text.trim().isNotEmpty) {
      _pendingAutoSend = false;
      _sendMessage();
    }
  }

  Future<void> _speak(String text) async {
    await _ttsService.speak(text);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text.trim();
    _messageController.clear();
    final provider = context.read<IeltsProvider>();
    await provider.sendMessage(message);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _ttsService.stop();
    _pulseController.dispose();
    _ieltsProvider?.stopExam(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ieltsProvider = context.watch<IeltsProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Yeni gelen asistan mesajlarını otomatik seslendir
    _checkAndSpeakLatestAssistantMessage(ieltsProvider);

    // Sınav aktif değilse başlangıç ekranı göster
    if (!ieltsProvider.isExamActive &&
        ieltsProvider.currentPart != IeltsPart.completed) {
      _scrolledToResults = false;
      return _buildStartScreen(context, ieltsProvider);
    }

    final isCompleted = ieltsProvider.currentPart == IeltsPart.completed;
    // Puan hazır olunca sonuç kartına bir kez kaydır
    if (isCompleted && !ieltsProvider.isEvaluating && !_scrolledToResults) {
      _scrolledToResults = true;
      _scrollToBottom();
    }

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
            // Header
            _buildHeader(context, ieltsProvider, primaryColor),
            // Messages & Topic Card combined in ListView
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount:
                    ieltsProvider.messages.length +
                    ((ieltsProvider.currentPart == IeltsPart.part2Prep ||
                            ieltsProvider.currentPart ==
                                IeltsPart.part2Speaking)
                        ? 1
                        : 0) +
                    (isCompleted ? 1 : 0),
                itemBuilder: (context, index) {
                  final showTopicCard =
                      ieltsProvider.currentPart == IeltsPart.part2Prep ||
                      ieltsProvider.currentPart == IeltsPart.part2Speaking;

                  // Sonuç kartı listenin sonunda: sabit bir sütunda kalınca
                  // küçük ekranlarda taşıyordu
                  if (isCompleted && index == ieltsProvider.messages.length) {
                    return _buildCompletedActions(context);
                  }

                  if (showTopicCard) {
                    if (index == 0) {
                      return _buildTopicCard(ieltsProvider);
                    }
                    final message = ieltsProvider.messages[index - 1];
                    return _buildMessageBubble(message);
                  } else {
                    final message = ieltsProvider.messages[index];
                    return _buildMessageBubble(message);
                  }
                },
              ),
            ),
            if (ieltsProvider.isLoading && !isCompleted)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            // Part 2 Prep - "Hazırım" butonu
            if (ieltsProvider.currentPart == IeltsPart.part2Prep)
              _buildReadyButton(ieltsProvider),
            // Normal input
            if (ieltsProvider.isExamActive &&
                ieltsProvider.currentPart != IeltsPart.part2Prep)
              _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen(BuildContext context, IeltsProvider provider) {
    final examType = provider.selectedExamType;
    final isToefl = examType == AcademicExamType.toefl;
    final accent = _accentFor(examType);
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
                  colors: _headerGradientFor(examType),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          examType.displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<IeltsProvider>(
                      builder: (context, provider, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Exam Format',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Exam Type Selector Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('🇬🇧 IELTS (Band 0-9)'),
                                    selected: provider.selectedExamType == AcademicExamType.ielts,
                                    showCheckmark: false,
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: provider.selectedExamType == AcademicExamType.ielts
                                          ? const Color(0xFF9333EA)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    selectedColor: const Color(0xFF9333EA),
                                    labelStyle: TextStyle(
                                      color: provider.selectedExamType == AcademicExamType.ielts ? Colors.white : const Color(0xFF334155),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    onSelected: (val) {
                                      if (val) provider.setExamType(AcademicExamType.ielts);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('🇺🇸 TOEFL iBT (Band 1-6)'),
                                    selected: provider.selectedExamType == AcademicExamType.toefl,
                                    showCheckmark: false,
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: provider.selectedExamType == AcademicExamType.toefl
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    selectedColor: const Color(0xFF2563EB),
                                    labelStyle: TextStyle(
                                      color: provider.selectedExamType == AcademicExamType.toefl ? Colors.white : const Color(0xFF334155),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    onSelected: (val) {
                                      if (val) provider.setExamType(AcademicExamType.toefl);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '🎯 ${provider.selectedExamType.displayName} Simulator',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (isToefl) ...[
                      _buildPartInfoCard(
                        'Task 1 - Listen and Repeat',
                        'Hear 7 sentences and repeat each one exactly',
                        '~3 min',
                        const Color(0xFF0EA5E9),
                        Icons.headphones_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildPartInfoCard(
                        'Task 2 - Take an Interview',
                        'Answer 4 questions on one campus or academic topic',
                        '~5 min',
                        const Color(0xFF10B981),
                        Icons.mic_external_on_outlined,
                      ),
                    ] else ...[
                      _buildPartInfoCard(
                        'Part 1 - Introduction & Warm-up',
                        'Answer familiar personal, study, and career questions',
                        '4-5 min',
                        const Color(0xFF0EA5E9),
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      _buildPartInfoCard(
                        'Part 2 - Long Turn (Cue Card)',
                        'Speak for 1-2 minutes on an exam-style cue card',
                        '3-4 min',
                        const Color(0xFF10B981),
                        Icons.description_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildPartInfoCard(
                        'Part 3 - Abstract Discussion',
                        'Answer in-depth critical and societal questions',
                        '4-5 min',
                        const Color(0xFFF59E0B),
                        Icons.forum_outlined,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // 2025-2026 sınav tarzı konu kartları havuzu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.style_rounded, color: accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isToefl ? 'TOEFL-Style Task Pool' : '2025-2026 Exam-Style Topic Pool',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isToefl
                                ? 'Updated for the January 2026 TOEFL iBT format: Listen and Repeat with campus & museum announcements, and interviews on study habits, campus life and technology. Scored on the new 1-6 band scale.'
                                : 'Topics include: Artificial Intelligence in daily life, Overcoming Challenges, Cultural Heritage & Green Habits.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!context.watch<PremiumProvider>().isPremium && _freeExamStatusLoaded) ...[
                      _buildFreeExamBanner(context, accent),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _startExam(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Start Exam',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFCD34D).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Color(0xFFD97706),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'For a realistic exam experience, find a quiet place and use your microphone.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPartInfoCard(
    String title,
    String description,
    String duration,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              duration,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    IeltsProvider ieltsProvider,
    Color primaryColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _headerGradientFor(ieltsProvider.selectedExamType),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _showExitDialog(context);
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ieltsProvider.partTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  ieltsProvider.partDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          // Timer
          if (ieltsProvider.isExamActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    ieltsProvider.remainingSeconds <= 30
                        ? Colors.red.withOpacity(0.9)
                        : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    ieltsProvider.remainingTimeFormatted,
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
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Exit Exam'),
            content: const Text(
              'Are you sure you want to exit the exam? Your progress will not be saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  context.read<IeltsProvider>().clearExam();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Exit'),
              ),
            ],
          ),
    );
  }

  Widget _buildTopicCard(IeltsProvider ieltsProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                ieltsProvider.topicCardLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ieltsProvider.currentTopicCard ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ieltsProvider.topicCardBulletsHeader,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...ieltsProvider.topicCardBullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyButton(IeltsProvider ieltsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => ieltsProvider.skipPreparation(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'I\'m Ready, Start Speaking',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedActions(BuildContext context) {
    final ieltsProvider = context.watch<IeltsProvider>();
    // Satın alma sonrası kilitler anında açılsın
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final examAccent = _accentFor(ieltsProvider.selectedExamType);
    final bandScore = ieltsProvider.bandScore;
    final feedback = ieltsProvider.bandScoreFeedback;

    // Liste zaten 16px kenar boşluğu veriyor; sonuç kartları mesajlarla hizalı olsun
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          // Exam Score Display & Criteria Breakdown (Item 4.2)
          if (bandScore != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getBandScoreColor(bandScore, ieltsProvider.latestExamReport?.examType ?? ieltsProvider.selectedExamType),
                    _getBandScoreColor(bandScore, ieltsProvider.latestExamReport?.examType ?? ieltsProvider.selectedExamType).withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _getBandScoreColor(bandScore, ieltsProvider.latestExamReport?.examType ?? ieltsProvider.selectedExamType).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${(ieltsProvider.latestExamReport?.examType ?? ieltsProvider.selectedExamType).displayName} Estimated Score',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ieltsProvider.latestExamReport?.scoreDisplay ?? bandScore.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (ieltsProvider.latestExamReport != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      ieltsProvider.latestExamReport!.examType == AcademicExamType.toefl
                          ? 'CEFR ${ieltsProvider.latestExamReport!.cefrLevel} · ≈ ${toeflSpeakingLegacyRange(bandScore)} on the former 0-30 scale'
                          : 'CEFR ${ieltsProvider.latestExamReport!.cefrLevel}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (feedback != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      feedback,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),

            // Criteria Scores Grid (ücretsiz kullanıcıda kilitli)
            if (ieltsProvider.latestExamReport != null && ieltsProvider.latestExamReport!.criteriaScores.isNotEmpty)
              if (!isPremium)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Score by Criteria',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      _buildLockedSection(
                        accent: examAccent,
                        message: 'See your score for each of the '
                            '${ieltsProvider.latestExamReport!.criteriaScores.length} criteria',
                        placeholder: Row(
                          children: ieltsProvider.latestExamReport!.criteriaScores.keys.map((name) {
                            return Expanded(
                              child: Column(
                                children: [
                                  const Text('?.?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                  const SizedBox(height: 4),
                                  Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  const SizedBox(height: 60),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                )
              else
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Score by Criteria',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ieltsProvider.latestExamReport!.criteriaScores.entries.map((entry) {
                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                entry.value.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  entry.key,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),


            // Bir üst banda çıkmak için tavsiyeler (ücretsiz kullanıcıda kilitli)
            if (ieltsProvider.latestExamReport != null &&
                (ieltsProvider.latestExamReport!.actionableTips.isNotEmpty ||
                    ieltsProvider.latestExamReport!.weaknesses.isNotEmpty))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to reach ${_nextTargetLabel(ieltsProvider.latestExamReport!)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 10),
                    if (!isPremium)
                      _buildLockedSection(
                        accent: examAccent,
                        message: 'Get personal tips to improve your score',
                        placeholder: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                            3,
                            (_) => const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text('• Practice this specific skill every day to raise your score',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                            ),
                          )..add(const SizedBox(height: 40)),
                        ),
                      )
                    else
                      ...[
                        ...ieltsProvider.latestExamReport!.weaknesses,
                        ...ieltsProvider.latestExamReport!.actionableTips,
                      ].map(
                        (tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 16, color: examAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(tip, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // PDF Report Share Button
            if (ieltsProvider.latestExamReport != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!isPremium) {
                      showPremiumPopup(context, triggerContext: 'exam_report');
                      return;
                    }
                    PdfReportService.shareOrPrintPdf(ieltsProvider.latestExamReport!);
                  },
                  icon: Icon(isPremium ? Icons.picture_as_pdf_rounded : Icons.lock_rounded, size: 20),
                  label: Text(isPremium ? 'Download / Share PDF Exam Report' : 'Unlock PDF Exam Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ] else if (ieltsProvider.isEvaluating)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Calculating your estimated score & PDF report...'),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Yeni sınavda format seçebilmek için başlangıç ekranına dön
                context.read<IeltsProvider>().clearExam();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentFor(ieltsProvider.selectedExamType),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start New Exam',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context.read<IeltsProvider>().clearExam();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentFor(ieltsProvider.selectedExamType),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  /// Ücretsiz kullanıcı için haftalık ücretsiz sınav durumu
  Widget _buildFreeExamBanner(BuildContext context, Color accent) {
    final available = _nextFreeExamAt == null;
    final daysLeft = available
        ? 0
        : (_nextFreeExamAt!.difference(DateTime.now()).inHours / 24).ceil().clamp(1, 7);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: available ? const Color(0xFFECFDF5) : const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: available ? const Color(0xFFA7F3D0) : const Color(0xFFE9D5FF)),
      ),
      child: Row(
        children: [
          Text(available ? '🎁' : '⏳', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available ? 'Your free mock test this week is ready' : 'Free mock test used this week',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Free users get 1 full mock test every 7 days.'
                      : 'Next free test in $daysLeft day${daysLeft == 1 ? '' : 's'}. Go Premium for unlimited tests.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (!available)
            TextButton(
              onPressed: () => showPremiumPopup(context, triggerContext: 'ielts'),
              child: Text('Upgrade', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  /// Ücretsiz kullanıcıda kilitli bölüm: içerik yerine yer tutucu bulanık gösterilir
  /// (gerçek değerler ekran okuyucuya da sızmasın diye çizilmez)
  Widget _buildLockedSection({
    required Widget placeholder,
    required String message,
    required Color accent,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: placeholder,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, color: accent, size: 22),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => showPremiumPopup(context, triggerContext: 'exam_report'),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Unlock Full Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Bir üst hedef skor (IELTS +0.5 / 9, TOEFL +0.5 / 6)
  String _nextTargetLabel(ExamReport report) {
    final next = (report.score + 0.5).clamp(0.0, report.examType.maxScore);
    return report.examType == AcademicExamType.ielts
        ? 'Band ${next.toStringAsFixed(1)}'
        : '${next.toStringAsFixed(1)} / 6';
  }

  /// Sınav türüne göre tema rengi (IELTS mor, TOEFL mavi) - ana ekran kartlarıyla uyumlu
  Color _accentFor(AcademicExamType type) =>
      type == AcademicExamType.toefl ? const Color(0xFF2563EB) : const Color(0xFF9333EA);

  List<Color> _headerGradientFor(AcademicExamType type) => type == AcademicExamType.toefl
      ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
      : const [Color(0xFF9333EA), Color(0xFF7C3AED)];

  Color _getBandScoreColor(double rawScore, [AcademicExamType type = AcademicExamType.ielts]) {
    // TOEFL (1-6) skorunu IELTS bant ölçeğine çevir
    final score = rawScore / type.maxScore * 9.0;
    if (score >= 7.5) return const Color(0xFF10B981); // Yeşil - Excellent
    if (score >= 6.0) return const Color(0xFF3B82F6); // Mavi - Good
    if (score >= 5.0) return const Color(0xFFF59E0B); // Turuncu - OK
    return const Color(0xFFEF4444); // Kırmızı - Needs improvement
  }

  /// TOEFL Listen and Repeat cümlesi: cevaplanana kadar metin gizli (dinleyerek tekrar)
  Widget _buildListenItemBubble(ConversationMessage message, int number, int? accuracy, Color accent) {
    final answered = accuracy != null;
    final accuracyColor = (accuracy ?? 0) >= 80
        ? const Color(0xFF10B981)
        : ((accuracy ?? 0) >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Icon(Icons.headphones_rounded, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Listen and repeat · $number/${IeltsProvider.listenItemTotal}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Play again',
                        icon: Icon(Icons.replay_rounded, size: 20, color: accent),
                        onPressed: () => _speak(message.content),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    answered ? message.content : 'Listen carefully, then repeat the sentence.',
                    style: TextStyle(
                      fontSize: answered ? 15 : 13,
                      color: answered ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                      fontStyle: answered ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  if (answered) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accuracyColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Accuracy: $accuracy%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accuracyColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == 'user';
    final examProvider = context.read<IeltsProvider>();
    final examAccent = _accentFor(examProvider.selectedExamType);
    final listenNumber = examProvider.listenItemNumber(message);
    if (listenNumber != null) {
      return _buildListenItemBubble(message, listenNumber, examProvider.listenAccuracy(message), examAccent);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  backgroundColor: examAccent.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.record_voice_over,
                    color: examAccent,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isUser
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      if (!isUser)
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 20),
                          onPressed: () => _speak(message.content),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.person, color: Colors.green),
                ),
              ],
            ],
          ),
          if (message.feedback != null ||
              (message.grammarCorrections?.isNotEmpty ?? false) ||
              (message.vocabularySuggestions?.isNotEmpty ?? false))
            _buildFeedback(message),
        ],
      ),
    );
  }

  Widget _buildFeedback(ConversationMessage message) {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 48),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                context.read<IeltsProvider>().selectedExamType == AcademicExamType.toefl
                    ? 'TOEFL Feedback'
                    : 'IELTS Feedback',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          if (message.feedback != null) ...[
            const SizedBox(height: 4),
            Text(message.feedback!, style: const TextStyle(fontSize: 12)),
          ],
          if (message.grammarCorrections?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            const Text(
              'Grammar Suggestions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            ...message.grammarCorrections!.map(
              (c) => Text('• $c', style: const TextStyle(fontSize: 11)),
            ),
          ],
          if (message.vocabularySuggestions?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            const Text(
              'Vocabulary Suggestions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            ...message.vocabularySuggestions!.map(
              (v) => Text('• $v', style: const TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: _isKeyboardMode ? _buildKeyboardInput() : _buildMicInput(),
      ),
    );
  }

  Widget _buildMicInput() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Mode Toggle Button (Corner)
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.keyboard_outlined, size: 28),
            onPressed: () => setState(() => _isKeyboardMode = true),
            color: Colors.grey.shade600,
          ),
        ),
        // Large Centered Mic
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTap: () async {
                if (!_speechEnabled) {
                  await _initSpeech();
                  if (!_speechEnabled) return;
                }
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _isListening
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening
                              ? Colors.red
                              : Theme.of(context).primaryColor)
                          .withOpacity(0.3),
                      blurRadius: 15 * _pulseAnimation.value,
                      spreadRadius: 5 * (_pulseAnimation.value - 1),
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKeyboardInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.mic_none),
          onPressed: () => setState(() => _isKeyboardMode = false),
          color: Colors.grey.shade600,
        ),
        Expanded(
          child: TextField(
            controller: _messageController,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          color: Theme.of(context).primaryColor,
          onPressed: _sendMessage,
        ),
      ],
    );
  }
}
