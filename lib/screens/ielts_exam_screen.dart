import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/ielts_provider.dart';
import '../models/models.dart';

class IeltsExamScreen extends StatefulWidget {
  const IeltsExamScreen({super.key});

  @override
  State<IeltsExamScreen> createState() => _IeltsExamScreenState();
}

class _IeltsExamScreenState extends State<IeltsExamScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _speechEnabled = false;
  IeltsProvider? _ieltsProvider;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ieltsProvider = context.read<IeltsProvider>();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-GB"); // British English for IELTS
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
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
    await context.read<IeltsProvider>().sendMessage(message);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    _ieltsProvider?.stopExam(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ieltsProvider = context.watch<IeltsProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Sınav aktif değilse başlangıç ekranı göster
    if (!ieltsProvider.isExamActive &&
        ieltsProvider.currentPart != IeltsPart.completed) {
      return _buildStartScreen(context, primaryColor);
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
            // Part 2 Topic Card (hazırlık aşamasında göster)
            if (ieltsProvider.currentPart == IeltsPart.part2Prep ||
                ieltsProvider.currentPart == IeltsPart.part2Speaking)
              _buildTopicCard(ieltsProvider),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: ieltsProvider.messages.length,
                itemBuilder: (context, index) {
                  final message = ieltsProvider.messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            if (ieltsProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            // Part 2 Prep - "Hazırım" butonu
            if (ieltsProvider.currentPart == IeltsPart.part2Prep)
              _buildReadyButton(ieltsProvider),
            // Completed state
            if (ieltsProvider.currentPart == IeltsPart.completed)
              _buildCompletedActions(context),
            // Normal input
            if (ieltsProvider.isExamActive &&
                ieltsProvider.currentPart != IeltsPart.part2Prep)
              _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen(BuildContext context, Color primaryColor) {
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
                  colors: [const Color(0xFF0EA5E9), const Color(0xFF3B82F6)],
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
                      const Expanded(
                        child: Text(
                          'IELTS Speaking',
                          style: TextStyle(
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
                    const Text(
                      '🎤 IELTS Speaking Sınav Simülasyonu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPartInfoCard(
                      'Part 1 - Introduction',
                      'Kendinizi tanıtın ve genel sorulara cevap verin',
                      '4-5 dakika',
                      const Color(0xFF0EA5E9),
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildPartInfoCard(
                      'Part 2 - Long Turn',
                      'Verilen konu kartı hakkında 1-2 dakika konuşun',
                      '3-4 dakika',
                      const Color(0xFF10B981),
                      Icons.description_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildPartInfoCard(
                      'Part 3 - Discussion',
                      'Part 2 ile ilgili derin sorulara cevap verin',
                      '4-5 dakika',
                      const Color(0xFFF59E0B),
                      Icons.forum_outlined,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<IeltsProvider>().startExam();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Sınava Başla',
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
                          const Text('💡', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Gerçek sınav ortamı için sessiz bir ortamda olun ve mikrofonu kullanın.',
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
          colors: [const Color(0xFF0EA5E9), const Color(0xFF3B82F6)],
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
            title: const Text('Sınavdan Çık'),
            content: const Text(
              'Sınavdan çıkmak istediğinize emin misiniz? İlerlemeniz kaydedilmeyecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  context.read<IeltsProvider>().clearExam();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Çık'),
              ),
            ],
          ),
    );
  }

  Widget _buildTopicCard(IeltsProvider ieltsProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
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
              const Text(
                'Topic Card',
                style: TextStyle(
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
          const Text(
            'You should say:',
            style: TextStyle(
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
            'Hazırım, Konuşmaya Başla',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedActions(BuildContext context) {
    final ieltsProvider = context.watch<IeltsProvider>();
    final bandScore = ieltsProvider.bandScore;
    final feedback = ieltsProvider.bandScoreFeedback;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Band Score Display
          if (bandScore != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getBandScoreColor(bandScore),
                    _getBandScoreColor(bandScore).withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _getBandScoreColor(bandScore).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'IELTS Band Score',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bandScore.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    '/ 9.0',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
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
            )
          else if (ieltsProvider.isLoading)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Puanınız hesaplanıyor...'),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<IeltsProvider>().clearExam();
                context.read<IeltsProvider>().startExam();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Yeni Sınav Başlat',
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ana Sayfaya Dön',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBandScoreColor(double score) {
    if (score >= 7.5) return const Color(0xFF10B981); // Yeşil - Excellent
    if (score >= 6.0) return const Color(0xFF3B82F6); // Mavi - Good
    if (score >= 5.0) return const Color(0xFFF59E0B); // Turuncu - OK
    return const Color(0xFFEF4444); // Kırmızı - Needs improvement
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
                  backgroundColor: const Color(0xFF9333EA).withOpacity(0.2),
                  child: const Icon(
                    Icons.record_voice_over,
                    color: Color(0xFF9333EA),
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
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
              SizedBox(width: 4),
              Text(
                'IELTS Feedback',
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
              '📝 Grammar:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            ...message.grammarCorrections!.map(
              (c) => Text('• $c', style: const TextStyle(fontSize: 11)),
            ),
          ],
          if (message.vocabularySuggestions?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            const Text(
              '📚 Vocabulary:',
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
              onPressed: () async {
                if (!_speechEnabled) {
                  // Tekrar başlatmayı dene
                  await _initSpeech();
                  if (!_speechEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Mikrofon başlatılamadı. Ayarlardan izinleri kontrol edin.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
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
                    hintText: 'Cevabınızı yazın veya sesli yanıt verin...',
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
