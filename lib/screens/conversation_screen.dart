import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/conversation_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/user_provider.dart';
import '../models/models.dart';
import '../widgets/premium_popup.dart';

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
  final FlutterTts _flutterTts = FlutterTts();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isListening = false;
  bool _speechEnabled = false;
  bool _pendingAutoSend = false;
  bool _isRecording = false;
  bool _isRecorderReady = false;
  String? _recordedFilePath;
  bool _hasShownTimeUpDialog = false;
  bool _isKeyboardMode = false;

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
    _initTts();
    _initRecorder();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to provider for safe access in dispose()
    _conversationProvider = context.read<ConversationProvider>();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('🎤 Speech status: $status');
          if (status == 'done' && mounted) {
            _pulseController.stop();
            _pulseController.reset();
            setState(() => _isListening = false);
            // Kullanıcı mikrofonu manuel kapattıysa mesajı otomatik gönder
            if (_pendingAutoSend) {
              _pendingAutoSend = false;
              if (_messageController.text.trim().isNotEmpty) {
                _sendMessage();
              }
            }
          } else if (status == 'listening' && mounted) {
            _pulseController.repeat(reverse: true);
          }
        },
        onError: (error) {
          debugPrint('❌ Speech error: $error');
          if (mounted) {
            _pulseController.stop();
            _pulseController.reset();
            setState(() => _isListening = false);
          }
        },
      );
      debugPrint('🎤 Speech initialized: $_speechEnabled');
    } catch (e) {
      debugPrint('❌ Speech init exception: $e');
      _speechEnabled = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
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

    // Mevcut metni koru - tekrar basınca üstüne eklensin
    final existingText = _messageController.text.trim();

    // Önce dinlemeyi başlat (await yok - gecikmeyi önler)
    _speech.listen(
      onResult: (result) {
        debugPrint('🎤 Recognized: ${result.recognizedWords}');
        setState(() {
          if (existingText.isNotEmpty) {
            _messageController.text = '$existingText ${result.recognizedWords}';
          } else {
            _messageController.text = result.recognizedWords;
          }
        });
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
      listenMode: stt.ListenMode.dictation,
    );

    // Sonra UI'yı güncelle
    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    _pendingAutoSend = true;
    await _speech.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text.trim();
    _messageController.clear();
    final provider = context.read<ConversationProvider>();
    await provider.sendMessage(message);
    // Otomatik sesli okuma - AI cevabını hemen oku
    final messages = provider.messages;
    if (messages.isNotEmpty && messages.last.role == 'assistant') {
      _speak(messages.last.content);
    }
    _scrollToBottom();
  }

  void _handleTimeUp() {
    if (_hasShownTimeUpDialog) return;
    _hasShownTimeUpDialog = true;

    final isPremium = context.read<PremiumProvider>().isPremium;
    final conversationProvider = context.read<ConversationProvider>();
    final userProvider = context.read<UserProvider>();

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
        Navigator.of(context).pop();
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
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
                    onPressed: () {
                      conversationProvider.stopTimer();
                      Navigator.pop(context);
                    },
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
                  const SizedBox(width: 8),
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
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
              SizedBox(width: 4),
              Text(
                'Feedback',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
