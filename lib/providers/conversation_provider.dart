import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/mistake_vault_service.dart';

class ConversationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<ConversationMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  Scenario? _currentScenario;

  // Timer özellikleri
  Timer? _timer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  bool _isTimeUp = false;
  VoidCallback? _onTimeUp;

  List<ConversationMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Scenario? get currentScenario => _currentScenario;
  int get remainingSeconds => _remainingSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isTimeUp => _isTimeUp;

  String get remainingTimeFormatted {
    if (_currentScenario != null && _currentScenario!.estimatedTime <= 0) {
      return '∞';
    }
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void setScenario(Scenario scenario, {VoidCallback? onTimeUp}) {
    _currentScenario = scenario;
    _messages = [];
    _error = null;
    _isTimeUp = false;
    _onTimeUp = onTimeUp;

    // Timer'ı başlat (senaryo süresi dakika cinsinden)
    _startTimer(scenario.estimatedTime);

    // Senaryo başlangıç mesajı
    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content: _getScenarioGreeting(scenario.id),
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void _startTimer(int durationMinutes) {
    if (durationMinutes <= 0) {
      _remainingSeconds = 0;
      _elapsedSeconds = 0;
      _timer?.cancel();
      return;
    }

    _remainingSeconds = durationMinutes * 60;
    _elapsedSeconds = 0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSeconds++;
        notifyListeners();
      } else {
        _timer?.cancel();
        _isTimeUp = true;
        _onTimeUp?.call();
        notifyListeners();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  void resetTimer() {
    if (_currentScenario != null) {
      _isTimeUp = false;
      _startTimer(_currentScenario!.estimatedTime);
    }
  }

  /// Premium kullanıcılar için süreyi uzat
  void extendTime(int additionalMinutes) {
    _remainingSeconds += additionalMinutes * 60;
    _isTimeUp = false;

    // Timer'ı yeniden başlat
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSeconds++;
        notifyListeners();
      } else {
        _timer?.cancel();
        _isTimeUp = true;
        _onTimeUp?.call();
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Geçen süreyi dakika olarak döndür
  int get elapsedMinutes => _elapsedSeconds ~/ 60;

  String _getScenarioGreeting(String scenarioId) {
    if (_currentScenario != null && _currentScenario!.greeting != null && _currentScenario!.greeting!.isNotEmpty) {
      return _currentScenario!.greeting!;
    }
    switch (scenarioId) {
      case 'restaurant':
        return "Hello! Welcome to our restaurant. How can I help you today?";
      case 'job_interview':
        return "Good morning! Thank you for coming. Please have a seat. Let's start with you telling me a bit about yourself.";
      case 'shopping':
        return "Hi there! Welcome to our store. Are you looking for something specific today?";
      case 'airport':
        return "Good day! Welcome to check-in. May I see your passport and booking reference, please?";
      case 'small_talk':
        return "Hey! Nice to meet you! I'm always excited to meet new people. What brings you here today?";
      default:
        return "Hello! Let's practice English together!";
    }
  }

  void _addMessage(ConversationMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// Canlı Akış (Streaming Responses - Item 2.3)
  ///
  /// [onSentenceReady] her tamamlanan cümle için sırayla çağrılır; böylece TTS
  /// ilk cümleyi hemen okumaya başlar ve cevabın geri kalanı da seslendirilir.
  /// [onStreamingCompleted] hata olsa bile her durumda en sonda çağrılır.
  Future<void> sendStreamingMessage({
    required String userMessage,
    void Function(String sentence)? onSentenceReady,
    VoidCallback? onStreamingCompleted,
  }) async {
    if (userMessage.trim().isEmpty || _currentScenario == null) return;

    // Kullanıcı mesajını ekle
    final userMsgIndex = _messages.length;
    _addMessage(
      ConversationMessage(
        role: 'user',
        content: userMessage,
        timestamp: DateTime.now(),
      ),
    );

    _isLoading = true;
    _error = null;
    notifyListeners();

    // Telaffuz analizini arka planda asenkron başlat (Item 2.2)
    _evaluateUserMessagePronunciation(userMsgIndex, userMessage);

    // AI placeholder mesajı ekle
    final aiMsgIndex = _messages.length;
    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      ),
    );

    // Seslendirilmek üzere gönderilen metnin uzunluğu
    int spokenLength = 0;
    void emitSentences(String text, {bool flush = false}) {
      if (onSentenceReady == null) return;
      final pending = text.substring(spokenLength);
      // Cümle sonu: . ! ? (ve ardından boşluk). Akış ortasında "3." gibi
      // yarım ifadeleri bölmemek için boşluk şartı aranır.
      final boundaries = RegExp(r'''[.!?]+["')\]]*\s+''').allMatches(pending);
      int consumed = 0;
      for (final m in boundaries) {
        // Önceki sınırdan bu sınıra kadar olan metnin tamamı bir cümle
        final sentence = pending.substring(consumed, m.end).trim();
        consumed = m.end;
        if (sentence.isNotEmpty) onSentenceReady(sentence);
      }
      spokenLength += consumed;
      if (flush) {
        final rest = text.substring(spokenLength).trim();
        spokenLength = text.length;
        if (rest.isNotEmpty) onSentenceReady(rest);
      }
    }

    try {
      // Mevcut kullanıcı mesajı ve boş AI mesajı hariç geçmiş
      // (backend kullanıcı mesajını ayrıca "User's new message" olarak ekliyor)
      final history = _messages
          .sublist(0, userMsgIndex)
          .where((msg) => msg.role == 'user' || msg.role == 'assistant')
          .map((msg) => msg.toJson())
          .toList();

      final stream = _apiService.streamMessage(
        scenarioId: _currentScenario!.id,
        userMessage: userMessage,
        conversationHistory: history,
        customSystemPrompt: _currentScenario!.customSystemPrompt,
      );

      String accumulatedText = '';
      List<String>? grammarCorrections;
      List<String>? vocabularySuggestions;
      String? feedback;

      await for (final event in stream) {
        final type = event['type'];

        if (type == 'chunk') {
          final String chunk = event['text'] ?? '';
          accumulatedText += chunk;
          // Akış sırasında konuşma sıfırlandıysa (Reset) sessizce çık
          if (aiMsgIndex >= _messages.length) return;

          // Mesajı güncelle
          _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
            content: accumulatedText,
            isStreaming: true,
          );
          notifyListeners();

          // Tamamlanan cümleleri hemen TTS'e aktar (ilk ses ~0.5s'de başlar)
          emitSentences(accumulatedText);
        } else if (type == 'feedback') {
          feedback = event['feedback'];
          grammarCorrections = event['grammar_corrections'] != null
              ? List<String>.from(event['grammar_corrections'])
              : null;
          vocabularySuggestions = event['vocabulary_suggestions'] != null
              ? List<String>.from(event['vocabulary_suggestions'])
              : null;
        } else if (type == 'done') {
          break;
        }
      }

      if (aiMsgIndex >= _messages.length) return;

      final hasText = accumulatedText.trim().isNotEmpty;
      final finalText = hasText ? accumulatedText.trim() : "That's very interesting, tell me more!";
      // Kalan (noktalama ile bitmeyen) son kısmı da seslendir
      if (hasText) {
        emitSentences(accumulatedText, flush: true);
      } else {
        onSentenceReady?.call(finalText);
      }

      // Akış bittiğinde son halini kaydet
      _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
        content: finalText,
        isStreaming: false,
        grammarCorrections: grammarCorrections,
        vocabularySuggestions: vocabularySuggestions,
        feedback: feedback,
      );

      // Hata Defterine (Mistake Vault - Item 3.1) otomatik kaydet
      if (grammarCorrections != null && grammarCorrections.isNotEmpty) {
        importMistakesToVault(grammarCorrections, userMessage);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Streaming error: $e');
      const glitchMessage = "Sorry, I had a brief connection glitch. Could you repeat that?";
      if (aiMsgIndex < _messages.length) {
        _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
          content: glitchMessage,
          isStreaming: false,
        );
      }
      onSentenceReady?.call(glitchMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
      // Arama ekranı bu çağrıya göre dinlemeye geri döner; hata olsa da çağrılmalı
      onStreamingCompleted?.call();
    }
  }

  /// Arka planda telaffuz analizi yap ve kullanıcı mesajına bağla
  Future<void> _evaluateUserMessagePronunciation(int msgIndex, String userText) async {
    try {
      final result = await _apiService.evaluatePronunciation(
        targetSentence: userText,
        spokenText: userText,
      );
      if (msgIndex < _messages.length && _messages[msgIndex].role == 'user') {
        _messages[msgIndex] = _messages[msgIndex].copyWith(
          pronunciationResult: result,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Hata Defterine Kayıt (Item 3.1)
  void importMistakesToVault(List<String> corrections, String userMessage) {
    try {
      importMistakeDynamic(corrections, userMessage, _currentScenario?.title ?? 'Conversation Practice');
    } catch (_) {}
  }

  void importMistakeDynamic(List<String> corrections, String userMessage, String title) async {
    try {
      final mistakeService = (await importMistakeVaultService());
      await mistakeService.autoRecordFromAiCorrections(
        corrections: corrections,
        userMessage: userMessage,
        scenarioTitle: title,
      );
    } catch (_) {}
  }

  dynamic importMistakeVaultService() async {
    // Dynamic import to avoid tight coupling if not needed
    return MistakeVaultService();
  }

  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || _currentScenario == null) return;

    // Use streaming for smoother UX
    await sendStreamingMessage(userMessage: userMessage);
  }

  void clearConversation() {
    _timer?.cancel();
    _messages = [];
    _currentScenario = null;
    _error = null;
    _isTimeUp = false;
    _remainingSeconds = 0;
    _elapsedSeconds = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
