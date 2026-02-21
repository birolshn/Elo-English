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

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isRecording = false;
  bool _isRecorderReady = false;
  String? _recordedFilePath;
  bool _hasShownTimeUpDialog = false;

  // Store reference to provider for use in dispose()
  ConversationProvider? _conversationProvider;

  @override
  void initState() {
    super.initState();
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
    _speechEnabled = await _speech.initialize();
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
    if (!_speechEnabled) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _messageController.text = result.recognizedWords;
        });
      },
      // Don't specify localeId - use device's default language
      // This allows Turkish names to be recognized correctly
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text.trim();
    _messageController.clear();
    await context.read<ConversationProvider>().sendMessage(message);
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
        Navigator.of(context).pushReplacementNamed('/scenarios');
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
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
        appBar: AppBar(title: const Text('Konuşma')),
        body: const Center(child: Text('Senaryo seçilmedi')),
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
                              title: const Text('Konuşmayı Sıfırla?'),
                              content: const Text(
                                'Tüm konuşma geçmişi silinecek.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('İptal'),
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
                                  child: const Text('Sıfırla'),
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
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.smart_toy, color: Colors.blue),
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
                'Geri Bildirim',
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
              '📝 Gramer:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            ...message.grammarCorrections!.map(
              (c) => Text('• $c', style: const TextStyle(fontSize: 11)),
            ),
          ],
          if (message.vocabularySuggestions?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            const Text(
              '📚 Kelime önerileri:',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color:
                    _isListening
                        ? Colors.red
                        : (_speechEnabled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400),
              ),
              onPressed: () {
                if (!_speechEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Mikrofon izni verilmedi veya cihaz desteklemiyor.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Mesajınızı yazın...',
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
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
