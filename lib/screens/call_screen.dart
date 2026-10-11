import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/models.dart';
import '../providers/conversation_provider.dart';
import '../providers/premium_provider.dart';
import '../services/premium_gate_service.dart';
import '../widgets/premium_popup.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';
import '../services/speech_error_helper.dart';

enum CallState { connecting, aiSpeaking, userSpeaking, processing }

class CallScreen extends StatefulWidget {
  final Scenario scenario;

  const CallScreen({super.key, required this.scenario});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TtsService _ttsService = TtsService();

  CallState _callState = CallState.connecting;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  String _currentSubtitle = 'Connecting to AI Tutor...';
  String _recognizedWords = '';
  Timer? _silenceTimer;
  Timer? _restartTimer;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;

  // Her dinleme oturumuna bir numara verilir; eski oturumlardan gelen geç
  // callback'ler (onResult / status / error) bu sayede yok sayılır.
  int _listenSession = 0;
  // Kullanıcının cümlesi bir kez gönderilsin (silence timer + finalResult + done yarışı)
  bool _isSubmitting = false;
  // AI cevabının akışı tamamlandı mı (TTS kuyruğu boşalsa bile akış sürebilir)
  bool _streamDone = true;
  bool _isEnding = false;
  String _aiSubtitle = '';
  int _consecutiveErrors = 0;

  // Kullanıcı konuşmayı bıraktıktan sonra cevabı göndermek için beklenen sessizlik
  static const Duration _silenceThreshold = Duration(milliseconds: 1600);

  late AnimationController _rippleController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startDurationTimer();
    _initCall();
  }

  // Ücretsiz kullanıcı: günde 3 dk arama (premium: sınırsız)
  final PremiumGateService _gate = PremiumGateService();
  bool _isPremium = true;
  int? _freeSecondsLeft;
  int _unsavedCallSeconds = 0;
  bool _limitReached = false;

  void _startDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callDurationSeconds++;
      });
      if (!_isPremium && _freeSecondsLeft != null && !_isEnding) {
        _unsavedCallSeconds++;
        _freeSecondsLeft = _freeSecondsLeft! - 1;
        if (_unsavedCallSeconds >= 10) _flushCallSeconds();
        if (_freeSecondsLeft! <= 0) _onFreeLimitReached();
      }
    });
  }

  void _flushCallSeconds() {
    final seconds = _unsavedCallSeconds;
    _unsavedCallSeconds = 0;
    _gate.addCallSeconds(seconds);
  }

  String get _formattedFreeLeft {
    final left = (_freeSecondsLeft ?? 0).clamp(0, PremiumGateService.freeCallSecondsPerDay);
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  /// Günlük ücretsiz süre bitti: aramayı kapat, paywall'u göster, sohbete dön
  Future<void> _onFreeLimitReached() async {
    if (_limitReached) return;
    _limitReached = true;
    _flushCallSeconds();
    _shutdownAudio();
    if (!mounted) return;
    setState(() {
      _callState = CallState.processing;
      _currentSubtitle = "You've used today's free call minutes.";
    });
    await showPremiumPopup(context, triggerContext: 'call_limit');
    if (mounted) Navigator.of(context).pop();
  }

  String get _formattedDuration {
    final minutes = _callDurationSeconds ~/ 60;
    final seconds = _callDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initCall() async {
    // Açılış cümlesi yerelde; ilk backend isteği kullanıcının cevabı olacak
    ApiService.warmUp();
    _isPremium = context.read<PremiumProvider>().isPremium;
    if (!_isPremium) {
      final left = await _gate.remainingFreeCallSeconds();
      if (!mounted) return;
      setState(() => _freeSecondsLeft = left);
      if (left <= 0) {
        _onFreeLimitReached();
        return;
      }
    }

    await _ttsService.initialize();
    // Sohbet ekranından kalan seslendirmeyi kes
    await _ttsService.stop();

    bool speechAvailable = false;
    try {
      speechAvailable = await _speech.initialize();
    } catch (e) {
      debugPrint('📞 Call STT init error: $e');
    }
    // SpeechToText tekil (singleton) ve initialize() ikinci kez çağrıldığında
    // dinleyicileri güncellemiyor; bu ekranın dinleyicilerini elle bağlıyoruz.
    _speech.statusListener = _onSpeechStatus;
    _speech.errorListener = _onSpeechError;

    if (!mounted || _isEnding) return;

    if (!speechAvailable) {
      setState(() {
        _callState = CallState.processing;
        _currentSubtitle =
            'Speech recognition is not available. Please allow microphone and speech permissions in Settings.';
      });
      return;
    }

    _ttsService.setCompletionHandler(_onTtsQueueFinished);
    await _ttsService.setSpeakerphone(_isSpeakerOn);
    if (!mounted || _isEnding) return;

    // Konuşma devam ediyorsa son AI mesajıyla, yoksa senaryo karşılamasıyla başla
    final provider = context.read<ConversationProvider>();
    String greeting = "Hello! I am ready to talk with you. How are you doing today?";
    final lastAssistant = provider.messages.lastWhere(
      (m) => m.role == 'assistant' && m.content.trim().isNotEmpty,
      orElse: () => ConversationMessage(role: '', content: '', timestamp: DateTime.now()),
    );
    if (lastAssistant.role == 'assistant') {
      greeting = lastAssistant.content;
    } else if (widget.scenario.greeting != null && widget.scenario.greeting!.isNotEmpty) {
      greeting = widget.scenario.greeting!;
    }

    _streamDone = true;
    _aiSubtitle = '';
    _onAiSentence(greeting);
  }

  /// AI cevabından gelen her cümle sırayla seslendirilir
  void _onAiSentence(String sentence) {
    if (!mounted || _isEnding) return;
    _aiSubtitle = _aiSubtitle.isEmpty ? sentence : '$_aiSubtitle $sentence';
    setState(() {
      _callState = CallState.aiSpeaking;
      _currentSubtitle = _aiSubtitle;
    });
    _ttsService.enqueue(sentence);
  }

  /// TTS kuyruğundaki tüm cümleler bitti
  void _onTtsQueueFinished() {
    if (!mounted || _isEnding) return;
    if (_streamDone) {
      // AI konuşmasını bitirdi: eller serbest dinlemeye geç
      _startListening();
    } else {
      // Ağ, sesten yavaş: sonraki cümleyi bekle
      setState(() => _callState = CallState.processing);
    }
  }

  void _onAiStreamCompleted() {
    if (!mounted || _isEnding) return;
    _streamDone = true;
    final messages = context.read<ConversationProvider>().messages;
    if (messages.isNotEmpty && messages.last.role == 'assistant') {
      setState(() => _currentSubtitle = messages.last.content);
    }
    if (!_ttsService.isSpeaking) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted || _isEnding) return;

    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _recognizedWords = '';
    _isSubmitting = false;
    final session = ++_listenSession;

    setState(() {
      _callState = CallState.userSpeaking;
      _currentSubtitle = _isMuted ? 'Microphone muted' : 'Listening to you... (Speak naturally)';
    });

    // Sessizdeyken sırayı kullanıcıda bekletiyoruz; unmute olunca dinleme başlar
    if (_isMuted) return;

    try {
      if (_speech.isListening) await _speech.cancel();
      if (!mounted || session != _listenSession) return;
      // Başka bir ekran dinleyicileri değiştirmiş olabilir; her seferinde bağla
      _speech.statusListener = _onSpeechStatus;
      _speech.errorListener = _onSpeechError;
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result, session),
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('📞 Call STT listen error: $e');
      _scheduleListenRestart(session);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int session) {
    if (!mounted || session != _listenSession || _callState != CallState.userSpeaking) return;
    _consecutiveErrors = 0;

    setState(() {
      _recognizedWords = result.recognizedWords;
      if (_recognizedWords.isNotEmpty) {
        _currentSubtitle = '"$_recognizedWords"';
      }
    });

    if (_recognizedWords.trim().isEmpty) return;

    if (result.finalResult) {
      _submitUserTurn();
      return;
    }

    // VAD: kullanıcı belirli bir süre sessiz kalırsa cümleyi otomatik gönder
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, () {
      if (session == _listenSession) _submitUserTurn();
    });
  }

  void _onSpeechStatus(String status) {
    debugPrint('📞 Call STT status: $status');
    if (!mounted || _isEnding || _callState != CallState.userSpeaking || _isMuted) return;
    if (status == stt.SpeechToText.doneStatus || status == stt.SpeechToText.notListeningStatus) {
      if (_recognizedWords.trim().isNotEmpty) {
        _submitUserTurn();
      } else {
        // Hiçbir şey söylenmeden oturum kapandı (iOS pauseFor / Android timeout)
        _scheduleListenRestart(_listenSession);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('📞 Call STT error: ${error.errorMsg} (permanent: ${error.permanent})');
    if (!mounted || _isEnding || _callState != CallState.userSpeaking || _isMuted) return;

    if (error.errorMsg == 'error_permission' || error.errorMsg == 'error_audio_error') {
      setState(() {
        _currentSubtitle = 'Microphone is not available. Please check permissions.';
      });
      return;
    }

    // Tanıma motoru hiç başlatılamıyorsa (ör. iOS 26.4 simülatörü) sonsuz yeniden deneme yapma
    if (SpeechErrorHelper.isFatal(error.errorMsg) && _recognizedWords.trim().isEmpty) {
      _restartTimer?.cancel();
      _listenSession++;
      _speech.cancel();
      setState(() {
        _currentSubtitle = SpeechErrorHelper.unavailableMessage.replaceFirst(
          'You can type your answer instead.',
          'You can continue in chat mode instead.',
        );
      });
      return;
    }

    if (_recognizedWords.trim().isNotEmpty) {
      _submitUserTurn();
    } else {
      _scheduleListenRestart(_listenSession);
    }
  }

  /// Dinlemeyi kısa bir gecikmeyle yeniden başlatır. status + error aynı anda
  /// gelebildiği için tek bir zamanlayıcıyla birleştirilir.
  void _scheduleListenRestart(int session) {
    _restartTimer?.cancel();
    _consecutiveErrors++;
    // Üst üste hatalarda motoru zorlamamak için gecikmeyi artır
    final delayMs = (300 * _consecutiveErrors).clamp(300, 3000);
    _restartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || _isEnding || session != _listenSession) return;
      if (_callState == CallState.userSpeaking && !_isMuted) {
        _startListening();
      }
    });
  }

  Future<void> _submitUserTurn() async {
    if (_isSubmitting || _isEnding || !mounted) return;
    _isSubmitting = true;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    // Bu oturumdan gelecek geç callback'leri geçersiz kıl
    _listenSession++;

    final spokenText = _recognizedWords.trim();
    await _speech.stop();
    if (!mounted || _isEnding) return;

    if (spokenText.isEmpty) {
      _startListening();
      return;
    }

    _consecutiveErrors = 0;
    _streamDone = false;
    _aiSubtitle = '';
    setState(() {
      _callState = CallState.processing;
      _currentSubtitle = 'Thinking...';
    });

    await context.read<ConversationProvider>().sendStreamingMessage(
      userMessage: spokenText,
      // Cümleler geldikçe seslendir (düşük gecikme - Item 2.3)
      onSentenceReady: _onAiSentence,
      onStreamingCompleted: _onAiStreamCompleted,
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      _silenceTimer?.cancel();
      _restartTimer?.cancel();
      _listenSession++;
      _speech.cancel();
      if (_callState == CallState.userSpeaking) {
        setState(() {
          _recognizedWords = '';
          _currentSubtitle = 'Microphone muted';
        });
      }
    } else if (_callState == CallState.userSpeaking) {
      _startListening();
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _ttsService.setSpeakerphone(_isSpeakerOn);
  }

  /// Aramayı kapat ve sohbet ekranına dön (konuşma geçmişi korunur)
  void _leaveCall() {
    _shutdownAudio();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _shutdownAudio() {
    if (_isEnding) return;
    _isEnding = true;
    _listenSession++;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _callDurationTimer?.cancel();
    _speech.statusListener = null;
    _speech.errorListener = null;
    _speech.cancel();
    _ttsService.setCompletionHandler(null);
    _ttsService.stop();
    _ttsService.resetAudioRoute();
  }

  @override
  void dispose() {
    if (_unsavedCallSeconds > 0) _flushCallSeconds();
    _shutdownAudio();
    _rippleController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark professional OLED theme
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 32),
                      // Sohbet moduna dön (konuşma geçmişi korunur)
                      onPressed: _leaveCall,
                    ),
                    Column(
                      children: [
                        Text(
                          widget.scenario.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _callState == CallState.userSpeaking
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF38BDF8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formattedDuration,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        if (!_isPremium && _freeSecondsLeft != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Free: $_formattedFreeLeft left today',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 24),
                      onPressed: _leaveCall,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Center Animated Avatar & Waveform
              Stack(
                alignment: Alignment.center,
                children: [
                  // Animated Ripple Rings
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: RipplePainter(
                          progress: _rippleController.value,
                          color: _callState == CallState.userSpeaking
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          isActive: _callState == CallState.aiSpeaking || _callState == CallState.userSpeaking,
                        ),
                        size: const Size(260, 260),
                      );
                    },
                  ),

                  // Avatar Circle
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _callState == CallState.userSpeaking
                            ? [const Color(0xFF059669), const Color(0xFF10B981)]
                            : [const Color(0xFF2563EB), const Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_callState == CallState.userSpeaking
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF38BDF8))
                              .withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _callState == CallState.userSpeaking
                            ? Icons.mic_rounded
                            : Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Status Indicator Text
              Text(
                _callState == CallState.aiSpeaking
                    ? 'AI Tutor Speaking...'
                    : _callState == CallState.userSpeaking
                        ? (_isMuted ? 'Muted - tap Unmute to talk' : 'Listening to you (Hands-Free)...')
                        : _callState == CallState.processing
                            ? 'Processing speech...'
                            : 'Connecting...',
                style: TextStyle(
                  color: _callState == CallState.userSpeaking ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Live Subtitle Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 80, maxHeight: 140),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        _currentSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Bottom Call Action Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    _buildCallButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      onTap: _toggleMute,
                    ),

                    // End Call Button (Big Red)
                    GestureDetector(
                      onTap: _leaveCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),

                    // Speaker Button
                    _buildCallButton(
                      icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      label: 'Speaker',
                      isActive: _isSpeakerOn,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  RipplePainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 70 + (maxRadius - 70) * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.5;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}
