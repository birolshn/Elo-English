import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum IeltsPart { part1, part2Prep, part2Speaking, part3, completed }

class IeltsQuestion {
  final String question;
  final IeltsPart part;
  final String? topicCard; // Part 2 için konu kartı

  IeltsQuestion({required this.question, required this.part, this.topicCard});
}

class IeltsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Sınav durumu
  IeltsPart _currentPart = IeltsPart.part1;
  List<ConversationMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _isExamActive = false;

  // Disposal flag to prevent notifyListeners after dispose
  bool _isDisposed = false;

  // Timer
  Timer? _timer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;

  // Part 2 konu kartı
  String? _currentTopicCard;
  List<String> _topicCardBullets = [];

  // Soru sayacı
  int _questionCount = 0;
  static const int _part1Questions = 4;
  static const int _part3Questions = 4;

  // Band score
  double? _bandScore;
  String? _bandScoreFeedback;

  // Getters
  IeltsPart get currentPart => _currentPart;
  List<ConversationMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isExamActive => _isExamActive;
  int get remainingSeconds => _remainingSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  String? get currentTopicCard => _currentTopicCard;
  List<String> get topicCardBullets => _topicCardBullets;
  double? get bandScore => _bandScore;
  String? get bandScoreFeedback => _bandScoreFeedback;

  String get remainingTimeFormatted {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get partTitle {
    switch (_currentPart) {
      case IeltsPart.part1:
        return 'Part 1 - Introduction';
      case IeltsPart.part2Prep:
        return 'Part 2 - Preparation';
      case IeltsPart.part2Speaking:
        return 'Part 2 - Long Turn';
      case IeltsPart.part3:
        return 'Part 3 - Discussion';
      case IeltsPart.completed:
        return 'Exam Completed';
    }
  }

  String get partDescription {
    switch (_currentPart) {
      case IeltsPart.part1:
        return 'Genel sorulara cevap verin';
      case IeltsPart.part2Prep:
        return 'Konuyu okuyun ve hazırlanın';
      case IeltsPart.part2Speaking:
        return 'Konu hakkında konuşun';
      case IeltsPart.part3:
        return 'Derin sorulara cevap verin';
      case IeltsPart.completed:
        return 'Sınav tamamlandı!';
    }
  }

  // Part 2 konu kartları
  static const List<Map<String, dynamic>> _topicCards = [
    {
      'topic': 'Describe a memorable journey you have taken',
      'bullets': [
        'Where you went',
        'Who you went with',
        'What you did there',
        'Why it was memorable',
      ],
    },
    {
      'topic': 'Describe a person who has influenced you',
      'bullets': [
        'Who this person is',
        'How you know them',
        'What they have done',
        'How they influenced you',
      ],
    },
    {
      'topic': 'Describe a book you have recently read',
      'bullets': [
        'What the book is about',
        'When you read it',
        'Why you chose this book',
        'What you learned from it',
      ],
    },
    {
      'topic': 'Describe a place you would like to visit',
      'bullets': [
        'Where it is',
        'How you learned about it',
        'What you would do there',
        'Why you want to visit',
      ],
    },
    {
      'topic': 'Describe a skill you would like to learn',
      'bullets': [
        'What the skill is',
        'Why you want to learn it',
        'How you would learn it',
        'How it would benefit you',
      ],
    },
  ];

  /// Sınavı başlat
  void startExam() {
    _currentPart = IeltsPart.part1;
    _messages = [];
    _error = null;
    _isExamActive = true;
    _questionCount = 0;
    _elapsedSeconds = 0;

    // Part 1 için 5 dakika
    _startTimer(5);

    // Hoşgeldin mesajı
    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content:
            "Good morning. My name is the IELTS examiner, and I'll be conducting your speaking test today. "
            "Could you please tell me your full name?",
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void _startTimer(int durationMinutes) {
    _timer?.cancel();
    _remainingSeconds = durationMinutes * 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Schedule the entire callback logic after current frame
      Future.microtask(() {
        // Don't notify if disposed
        if (_isDisposed) return;

        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _elapsedSeconds++;
          notifyListeners();
        } else {
          _handleTimeUp();
        }
      });
    });
  }

  void _handleTimeUp() {
    _timer?.cancel();

    switch (_currentPart) {
      case IeltsPart.part1:
        _transitionToPart2();
        break;
      case IeltsPart.part2Prep:
        _startPart2Speaking();
        break;
      case IeltsPart.part2Speaking:
        _transitionToPart3();
        break;
      case IeltsPart.part3:
        _completeExam();
        break;
      case IeltsPart.completed:
        break;
    }
  }

  void _transitionToPart2() {
    _currentPart = IeltsPart.part2Prep;
    _questionCount = 0;

    // Rastgele bir konu kartı seç
    final random = DateTime.now().millisecond % _topicCards.length;
    final card = _topicCards[random];
    _currentTopicCard = card['topic'];
    _topicCardBullets = List<String>.from(card['bullets']);

    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content:
            "Now, I'm going to give you a topic, and I'd like you to talk about it for one to two minutes. "
            "You have one minute to prepare. Here is your topic card.",
        timestamp: DateTime.now(),
      ),
    );

    // 1 dakika hazırlık süresi
    _startTimer(1);
    notifyListeners();
  }

  void _startPart2Speaking() {
    _currentPart = IeltsPart.part2Speaking;

    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content:
            "Your preparation time is over. Please begin speaking about the topic. "
            "Remember, you should speak for one to two minutes.",
        timestamp: DateTime.now(),
      ),
    );

    // 2 dakika konuşma süresi
    _startTimer(2);
    notifyListeners();
  }

  void _transitionToPart3() {
    _currentPart = IeltsPart.part3;
    _questionCount = 0;
    _currentTopicCard = null;
    _topicCardBullets = [];

    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content:
            "Thank you. Now, let's move on to Part 3 of the test. "
            "I'd like to discuss some more general topics related to what you just talked about.",
        timestamp: DateTime.now(),
      ),
    );

    // 5 dakika
    _startTimer(5);
    notifyListeners();
  }

  Future<void> _completeExam() async {
    _currentPart = IeltsPart.completed;
    _timer?.cancel();
    _isExamActive = false;
    _isLoading = true;
    notifyListeners();

    // Konuşma geçmişinden band score hesapla
    try {
      final history =
          _messages
              .where((msg) => msg.role == 'user' || msg.role == 'assistant')
              .map((msg) => msg.toJson())
              .toList();

      final result = await _apiService.evaluateIeltsSpeaking(history);
      _bandScore = (result['band_score'] as num?)?.toDouble();
      _bandScoreFeedback = result['feedback'] as String?;
    } catch (e) {
      debugPrint('Band score evaluation error: $e');
      _bandScore = null;
      _bandScoreFeedback = null;
    }

    _isLoading = false;

    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content:
            "Thank you very much. That's the end of the speaking test. "
            "You did a great job! Your responses showed good vocabulary and fluency. "
            "Keep practicing to improve even further!",
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void _addMessage(ConversationMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// Kullanıcı mesajı gönder
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || !_isExamActive) return;

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
      final response = await _apiService.sendIeltsMessage(
        part: _currentPart.index + 1,
        userMessage: userMessage,
        conversationHistory: history,
        topicCard: _currentTopicCard,
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

      // Soru sayısını artır ve gerekirse part değiştir
      _questionCount++;
      _checkPartTransition();
    } catch (e) {
      _error = e.toString();
      _addMessage(
        ConversationMessage(
          role: 'assistant',
          content: "Sorry, I'm having trouble. Please try again.",
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _checkPartTransition() {
    switch (_currentPart) {
      case IeltsPart.part1:
        if (_questionCount >= _part1Questions) {
          _transitionToPart2();
        }
        break;
      case IeltsPart.part2Speaking:
        // Part 2 timer ile kontrol ediliyor
        break;
      case IeltsPart.part3:
        if (_questionCount >= _part3Questions) {
          _completeExam();
        }
        break;
      default:
        break;
    }
  }

  /// Part 2 hazırlık bittiğinde manuel geçiş
  void skipPreparation() {
    if (_currentPart == IeltsPart.part2Prep) {
      _timer?.cancel();
      _startPart2Speaking();
    }
  }

  void stopExam({bool notify = true}) {
    _timer?.cancel();
    _isExamActive = false;
    if (notify && !_isDisposed) {
      notifyListeners();
    }
  }

  void clearExam({bool notify = true}) {
    _timer?.cancel();
    _messages = [];
    _currentPart = IeltsPart.part1;
    _isExamActive = false;
    _error = null;
    _questionCount = 0;
    _remainingSeconds = 0;
    _elapsedSeconds = 0;
    _currentTopicCard = null;
    _topicCardBullets = [];
    _bandScore = null;
    _bandScoreFeedback = null;
    if (notify && !_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
