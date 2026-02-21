import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

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

  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || _currentScenario == null) return;

    // Kullanıcı mesajını ekle
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

    try {
      // Konuşma geçmişini hazırla
      final history =
          _messages
              .where((msg) => msg.role == 'user' || msg.role == 'assistant')
              .map((msg) => msg.toJson())
              .toList();

      // API'ye gönder
      final response = await _apiService.sendMessage(
        scenarioId: _currentScenario!.id,
        userMessage: userMessage,
        conversationHistory: history,
      );

      // AI cevabını ekle
      _addMessage(
        ConversationMessage(
          role: 'assistant',
          content: response['ai_message'],
          timestamp: DateTime.now(),
          grammarCorrections:
              response['grammar_corrections'] != null
                  ? List<String>.from(response['grammar_corrections'])
                  : null,
          vocabularySuggestions:
              response['vocabulary_suggestions'] != null
                  ? List<String>.from(response['vocabulary_suggestions'])
                  : null,
          feedback: response['feedback'],
        ),
      );
    } catch (e) {
      _error = e.toString();
      _addMessage(
        ConversationMessage(
          role: 'assistant',
          content: "Sorry, I'm having trouble connecting. Please try again.",
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
