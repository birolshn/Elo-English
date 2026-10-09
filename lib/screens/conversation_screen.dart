import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/speech_error_helper.dart';
import '../services/tts_service.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/premium_provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../widgets/premium_popup.dart';
import '../providers/conversation_provider.dart';
import '../screens/call_screen.dart';
import '../widgets/pronunciation_dialog.dart';
import '../services/word_bank_service.dart';
import '../services/api_service.dart';
import '../services/mistake_vault_service.dart';
import '../services/premium_gate_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isListening = false;
  bool _speechEnabled = false;
  bool _pendingAutoSend = false;
  bool _isRecorderReady = false;
  bool _hasShownTimeUpDialog = false;
  bool _isKeyboardMode = false;
  bool _shouldBeListening = false;

  // Pulsating animation for mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Store reference to provider for use in dispose()
  ConversationProvider? _conversationProvider;

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
    _initTts().then((_) {
      // İlk mesajı otomatik seslendir (TTS hazır olduktan sonra)
      _speakFirstMessage();
    });
    _initRecorder();
  }

  Future<void> _speakFirstMessage() async {
    // Kısa bir gecikme ile TTS'in hazır olmasını bekle
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final messages = context.read<ConversationProvider>().messages;
    if (messages.isNotEmpty && messages.first.role == 'assistant') {
      _speak(messages.first.content);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to provider for safe access in dispose()
    _conversationProvider = context.read<ConversationProvider>();
  }

  Future<void> _initSpeech() async {
    try {
      // Önceki session'ı temizle (IELTS ekranından kalma olabilir)
      await _speech.cancel();
      
      _speechEnabled = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      _attachSpeechListeners();
      debugPrint('🎤 Conv Speech initialized: $_speechEnabled');
    } catch (e) {
      debugPrint('❌ Speech init exception: $e');
      _speechEnabled = false;
    }
    if (mounted) setState(() {});
  }

  /// SpeechToText tekil (singleton) ve initialize() ikinci kez çağrıldığında
  /// dinleyicileri güncellemiyor. Başka ekran (IELTS, arama, gölgeleme) kendi
  /// dinleyicilerini bağlamış olabileceği için her listen() öncesi yeniden bağlanır.
  void _attachSpeechListeners() {
    _speech.statusListener = _onSpeechStatus;
    _speech.errorListener = _onSpeechError;
  }

  // Tanıma motoru açılıp hemen kapanıyorsa (sonuçsuz) sonsuz yeniden başlatmayı önle
  DateTime? _listenStartedAt;
  int _rapidFailures = 0;

  Future<void> _onSpeechStatus(String status) async {
    debugPrint('🎤 Conv Speech status: $status');
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
    debugPrint('❌ Conv Speech error: $error');
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

  Future<void> _initTts() async {
    await _ttsService.initialize(language: 'en-US');
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return;
    }

    await _recorder.openRecorder();
    _isRecorderReady = true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      debugPrint('❌ Speech not enabled, trying to reinitialize...');
      await _initSpeech();
      if (!_speechEnabled) return;
    }

    _shouldBeListening = true;
    _listenStartedAt = DateTime.now();
    _attachSpeechListeners();
    // AI konuşurken mikrofon açılırsa sesi kes (yankı olmasın)
    _ttsService.stop();

    // Mevcut metni koru - tekrar basınca üstüne eklensin
    final existingText = _messageController.text.trim();

    // Önce dinlemeyi başlat (await yok - gecikmeyi önler)
    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) _rapidFailures = 0;
        debugPrint('🎤 Conv Recognized: ${result.recognizedWords} (final: ${result.finalResult})');
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

    // Sonra UI'yı güncelle
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
    if (_pendingAutoSend && mounted && _messageController.text.trim().isNotEmpty) {
      _pendingAutoSend = false;
      _sendMessage();
    }
  }

  Future<void> _speak(String text) async {
    await _ttsService.speak(text);
  }

  final PremiumGateService _gate = PremiumGateService();

  /// "Great session" teklifi için en az bu kadar kullanıcı mesajı
  static const int _sessionWinMinMessages = 4;

  /// Geri çıkış: ücretsiz ve giriş yapmış kullanıcıya iyi bir oturumdan sonra
  /// günde bir kez premium teklifi göster (onboarding denemesinde gösterme)
  Future<void> _handleExit() async {
    final provider = context.read<ConversationProvider>();
    provider.stopTimer();
    final isPremium = context.read<PremiumProvider>().isPremium;
    final isLoggedIn = context.read<AuthProvider>().isAuthenticated;
    final userMessages = provider.messages.where((m) => m.role == 'user').length;

    if (!isPremium &&
        isLoggedIn &&
        userMessages >= _sessionWinMinMessages &&
        await _gate.shouldShowSessionWin()) {
      await _gate.markSessionWinShown();
      if (!mounted) return;
      final corrections = provider.messages
          .expand((m) => m.grammarCorrections ?? const <String>[])
          .where((c) => MistakeVaultService.parseCorrection(c, '') != null)
          .length;
      await showSessionWinSheet(
        context,
        userMessages: userMessages,
        minutes: provider.elapsedMinutes,
        corrections: corrections,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text.trim();
    _messageController.clear();
    final provider = context.read<ConversationProvider>();
    _scrollToBottom();
    // Önceki cevabın seslendirmesi sürüyorsa kes
    await _ttsService.stop();

    await provider.sendStreamingMessage(
      userMessage: message,
      // Cümleler geldikçe sırayla seslendir (yalnızca ilk cümle değil)
      onSentenceReady: (sentence) {
        if (mounted) _ttsService.enqueue(sentence);
      },
      onStreamingCompleted: () {
        if (mounted) _scrollToBottom();
      },
    );
    _scrollToBottom();
  }

  void _handleTimeUp() {
    if (_hasShownTimeUpDialog) return;
    _hasShownTimeUpDialog = true;

    // Süre arama modundayken dolduysa önce arama ekranını kapat; aksi halde
    // diyalog aramanın üstünde açılır ve "Exit" yanlış ekranı kapatır.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      Navigator.of(context).popUntil((r) => r == route);
    }

    final isPremium = context.read<PremiumProvider>().isPremium;
    final conversationProvider = context.read<ConversationProvider>();
    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text(
                  'Trial Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You did a great job! Now let\'s create your account to continue practicing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      conversationProvider.clearConversation();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showConversationCompletedDialog(
      context,
      isPremium: isPremium,
      onContinue: () {
        // Premium kullanıcı için süreyi uzat
        conversationProvider.extendTime(5);
        _hasShownTimeUpDialog = false;
      },
      onExit: () {
        // Konuşmayı bitir ve senaryolar sayfasına dön
        if (conversationProvider.currentScenario != null) {
          userProvider.updateProgressAfterConversation(
            addedMinutes: conversationProvider.elapsedMinutes,
            completedScenario: conversationProvider.currentScenario!.id,
          );
        }
        conversationProvider.clearConversation();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _ttsService.stop();
    _pulseController.dispose();
    if (_isRecorderReady) {
      _recorder.closeRecorder();
    }
    // Timer'ı durdur - use saved reference instead of context.read
    _conversationProvider?.stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationProvider = context.watch<ConversationProvider>();
    final scenario = conversationProvider.currentScenario;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Süre dolduğunda dialog göster
    if (conversationProvider.isTimeUp && !_hasShownTimeUpDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTimeUp();
      });
    }

    if (scenario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: const Center(child: Text('Scenario not selected')),
      );
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
            // Curved header with timer
            Container(
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
                  colors: [primaryColor, primaryColor.withBlue(220)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _handleExit,
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          scenario.difficulty.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Timer Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          conversationProvider.remainingSeconds <= 60
                              ? Colors.red.withOpacity(0.9)
                              : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          conversationProvider.remainingTimeFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                    tooltip: 'Hands-Free Phone Call Mode',
                    onPressed: () async {
                      // Ücretsiz kullanıcının bugünkü arama dakikası bittiyse aramayı açma
                      if (!context.read<PremiumProvider>().isPremium &&
                          await _gate.remainingFreeCallSeconds() <= 0) {
                        if (!context.mounted) return;
                        showPremiumPopup(context, triggerContext: 'call_limit');
                        return;
                      }
                      // Dikte edilen metni göndermeden mikrofonu ve sesi kapat
                      _shouldBeListening = false;
                      _pendingAutoSend = false;
                      _pulseController.stop();
                      _pulseController.reset();
                      setState(() => _isListening = false);
                      await _speech.cancel();
                      await _ttsService.stop();
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallScreen(scenario: scenario),
                        ),
                      );
                      // Arama ekranı kendi STT dinleyicilerini bağlamıştı; geri al
                      if (mounted) {
                        _attachSpeechListeners();
                        _scrollToBottom();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Reset Conversation?'),
                              content: const Text(
                                'All conversation history will be deleted.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _hasShownTimeUpDialog = false;
                                    conversationProvider.setScenario(
                                      scenario,
                                      onTimeUp: _handleTimeUp,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: conversationProvider.messages.length,
                itemBuilder: (context, index) {
                  final message = conversationProvider.messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            if (conversationProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == 'user';

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
                  backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(25),
                  child: Icon(Icons.record_voice_over, color: Theme.of(context).colorScheme.primary, size: 20),
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

          // Telaffuz & Vurgu Analizi Butonu/Rozeti (Item 2.2)
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 48),
              child: InkWell(
                onTap: () {
                  if (message.pronunciationResult != null) {
                    PronunciationBottomSheet.show(context, message.pronunciationResult!, message.content);
                  } else {
                    // Quick analysis on demand
                    ApiService().evaluatePronunciation(
                      targetSentence: message.content,
                      spokenText: message.content,
                    ).then((res) {
                      if (context.mounted) {
                        PronunciationBottomSheet.show(context, res, message.content);
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (message.pronunciationResult != null
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 14,
                        color: message.pronunciationResult != null
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.pronunciationResult != null
                            ? 'Pronunciation: ${message.pronunciationResult!.overallScore}% 🎯'
                            : 'Check Accent & Phonetics 🎯',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: message.pronunciationResult != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'AI Feedback',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              // Yalnızca gerçekten deftere kaydedilen düzeltmeler için rozet göster
              if (message.grammarCorrections?.any(
                    (c) => MistakeVaultService.parseCorrection(c, '') != null,
                  ) ??
                  false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 10, color: Colors.brown),
                      SizedBox(width: 3),
                      Text(
                        'Saved to Vault 📒',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.brown),
                      ),
                    ],
                  ),
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
              'Vocabulary Suggestions (Tap star to save):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            ...message.vocabularySuggestions!.map(
              (v) => Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('• $v', style: const TextStyle(fontSize: 11)),
                    ),
                    InkWell(
                      onTap: () async {
                        await WordBankService().saveWord(
                          word: v,
                          meaning: 'Saved from conversation feedback',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "$v" to Word Bank! ⭐️'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 12, color: Colors.orange),
                            SizedBox(width: 2),
                            Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
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
        PositionImage(
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
              onTap: () {
                if (!_speechEnabled) return;
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
                  color: _isListening ? Colors.red : Theme.of(context).primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : Theme.of(context).primaryColor)
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
              hintText: 'Type your message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

class PositionImage extends StatelessWidget {
  final Widget child;
  final Alignment alignment;
  const PositionImage({super.key, required this.child, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(alignment: alignment, child: child);
  }
}
