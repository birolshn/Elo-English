import 'dart:async';
import 'dart:math';
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
  // Testlerde sahte servis verilebilsin diye dışarıdan alınabilir
  IeltsProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

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
  // TOEFL 2026: Task 1 = 7 Listen and Repeat cümlesi, Task 2 = 4 mülakat sorusu
  int get _part1Questions => _isToefl ? listenItemTotal : 4;
  int get _part3Questions => 4;

  // Sınav sonu puanlaması sürüyor mu (isLoading mesaj gönderimiyle paylaşıldığı için ayrı)
  bool _isEvaluating = false;
  bool get isEvaluating => _isEvaluating;

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

  bool get _isToefl => _selectedExamType == AcademicExamType.toefl;

  /// Konu kartı başlıkları (yalnızca IELTS Part 2'de gösterilir)
  String get topicCardLabel => 'Topic Card';
  String get topicCardBulletsHeader => 'You should say:';

  String get partTitle {
    if (_isToefl) {
      switch (_currentPart) {
        case IeltsPart.part1:
          return 'Task 1 - Listen and Repeat';
        case IeltsPart.part2Prep:
        case IeltsPart.part2Speaking:
        case IeltsPart.part3:
          return 'Task 2 - Take an Interview';
        case IeltsPart.completed:
          return 'Practice Test Completed';
      }
    }
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
    if (_isToefl) {
      switch (_currentPart) {
        case IeltsPart.part1:
          return 'Repeat each sentence exactly as you hear it';
        case IeltsPart.part2Prep:
        case IeltsPart.part2Speaking:
        case IeltsPart.part3:
          return 'Answer 4 questions on one topic';
        case IeltsPart.completed:
          return 'Your estimated score is ready';
      }
    }
    switch (_currentPart) {
      case IeltsPart.part1:
        return 'Answer general questions';
      case IeltsPart.part2Prep:
        return 'Read the topic and prepare';
      case IeltsPart.part2Speaking:
        return 'Speak about the topic';
      case IeltsPart.part3:
        return 'Answer in-depth questions';
      case IeltsPart.completed:
        return 'Exam completed!';
    }
  }

  AcademicExamType _selectedExamType = AcademicExamType.ielts;
  ExamReport? _latestExamReport;

  AcademicExamType get selectedExamType => _selectedExamType;
  ExamReport? get latestExamReport => _latestExamReport;

  void setExamType(AcademicExamType type) {
    // Sınav sürerken format değişmesin (mesajlar ve kartlar karışır)
    if (_isExamActive) return;
    _selectedExamType = type;
    notifyListeners();
  }

  // TOEFL iBT 2026 tarzı görev havuzu (resmi soru değildir).
  // Listen and Repeat: kısa cümleden uzun / karmaşık cümleye doğru zorlaşan 7 cümle
  static const List<List<String>> _toeflListenSets = [
    [
      'The library opens at eight.',
      'Please bring your student card.',
      'The bookstore is next to the main entrance.',
      'You can borrow up to ten books at a time.',
      'If you need help, ask the staff at the front desk.',
      'Group study rooms must be reserved at least one day in advance.',
      'Students who return books late cannot borrow new ones until the fine is paid.',
    ],
    [
      'Welcome to the science museum.',
      'Our tour starts in ten minutes.',
      'Please stay together with your group.',
      'The dinosaur exhibit is on the second floor.',
      'Photos are allowed, but please turn off your flash.',
      'The gallery we are entering now shows how the city has changed over time.',
      'Visitors who would like to learn more can join the evening lecture, which is free for students.',
    ],
    [
      'Classes begin next Monday.',
      'The schedule is posted online.',
      'Your advisor can help you choose your courses.',
      'Lab sessions take place every Thursday afternoon.',
      'If a class is full, you can join the waiting list.',
      'Students should check their university email regularly for important updates.',
      'Anyone who wants to change their major must submit a form before the end of the second week.',
    ],
  ];

  // Take an Interview: senaryo + ilk soru; sonraki 3 soruyu AI zorlaşarak sorar
  static const List<Map<String, String>> _toeflInterviews = [
    {
      'scenario': 'You are taking part in a university research study about student study habits.',
      'question': 'To begin, can you describe where and when you usually study?',
    },
    {
      'scenario': 'The student newspaper is interviewing students about food services on campus.',
      'question': 'First, how often do you eat on campus, and what do you usually have?',
    },
    {
      'scenario': 'Your professor is interviewing students about using technology in class.',
      'question': 'To start, which digital tools do you use most often for your classes?',
    },
    {
      'scenario': 'A city museum is surveying young people about visiting museums.',
      'question': 'To start, when did you last visit a museum, and what did you see there?',
    },
  ];

  static const int listenItemTotal = 7;

  List<String> _listenSentences = [];
  // Mesaj nesnesi -> cümle no / doğruluk (ConversationMessage == tanımlamıyor; kimlik eşitliği)
  final Map<ConversationMessage, int> _listenItemNumbers = Map.identity();
  final Map<ConversationMessage, int> _listenAccuracies = Map.identity();

  /// Mesaj bir "Listen and Repeat" cümlesiyse 1-7 arası sırası
  int? listenItemNumber(ConversationMessage message) => _listenItemNumbers[message];

  /// Kullanıcının bu cümleyi tekrar doğruluğu (%) - cevaplanmadıysa null
  int? listenAccuracy(ConversationMessage message) => _listenAccuracies[message];

  double? get _listenAverage => _listenAccuracies.isEmpty
      ? null
      : _listenAccuracies.values.reduce((a, b) => a + b) / _listenAccuracies.length;

  /// Kelime sırasını da dikkate alan tekrar doğruluğu (en uzun ortak alt dizi)
  static int repeatAccuracy(String target, String spoken) {
    List<String> words(String t) => t
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final a = words(target);
    final b = words(spoken);
    if (a.isEmpty || b.isEmpty) return 0;
    final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1] + 1
            : (dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1]);
      }
    }
    // Fazladan söylenen kelimeler de doğruluğu düşürsün
    final lcs = dp[a.length][b.length];
    return (200 * lcs / (a.length + b.length)).round().clamp(0, 100);
  }

  void _addListenItem() {
    final index = _questionCount;
    final message = ConversationMessage(
      role: 'assistant',
      content: _listenSentences[index],
      timestamp: DateTime.now(),
    );
    _listenItemNumbers[message] = index + 1;
    _addMessage(message);
  }

  /// Task 1 cevabı: AI çağrısı yok, cihazda puanlanır
  void _handleListenAnswer(String userMessage) {
    final prompt = _messages.lastWhere((m) => _listenItemNumbers.containsKey(m));
    _listenAccuracies[prompt] = repeatAccuracy(prompt.content, userMessage);
    _addMessage(
      ConversationMessage(
        role: 'user',
        content: userMessage,
        timestamp: DateTime.now(),
      ),
    );
    _questionCount++;
    if (_questionCount < listenItemTotal) {
      _addListenItem();
    } else {
      _transitionToToeflInterview();
    }
  }

  void _transitionToToeflInterview() {
    _currentPart = IeltsPart.part3;
    _questionCount = 0;
    final interview = _toeflInterviews[_random.nextInt(_toeflInterviews.length)];
    _toeflTaskPrompt = 'Interview scenario: ${interview['scenario']}\nFirst question (already asked): ${interview['question']}';
    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content: "Well done. Now, Task 2: Take an Interview. ${interview['scenario']} "
            "I will ask you four questions. ${interview['question']}",
        timestamp: DateTime.now(),
      ),
    );
    // Gerçek sınavda hazırlık yok; 4 soru için toplam 5 dk
    _startTimer(300);
    notifyListeners();
  }

  String? _toeflTaskPrompt;

  // 2025-2026 sınav tarzı konu kartları (sunucu havuzu yüklenemezse yedek)
  static const List<Map<String, dynamic>> _topicCards = [
    {
      'topic': 'Describe an occasion when you used an artificial intelligence tool to help you',
      'bullets': [
        'What AI tool or software you used',
        'What problem or task you needed assistance with',
        'How effectively the tool solved it',
        'And explain how you felt about using AI',
      ],
    },
    {
      'topic': 'Describe a difficult challenge you faced and successfully overcame',
      'bullets': [
        'What the challenge was',
        'When and where it occurred',
        'What specific steps you took to overcome it',
        'And explain what you learned from the experience',
      ],
    },
    {
      'topic': 'Describe a traditional celebration or cultural festival in your country',
      'bullets': [
        'What festival or celebration it is',
        'When and where it takes place',
        'What traditional foods or activities are involved',
        'And explain why this festival is meaningful to people',
      ],
    },
    {
      'topic': 'Describe an environmentally friendly habit you adopted in your daily routine',
      'bullets': [
        'What habit or change you made',
        'Why you decided to make this change',
        'How easy or difficult it was to maintain',
        'And explain what positive impact you think it has',
      ],
    },
    {
      'topic': 'Describe a memorable journey or trip you have taken',
      'bullets': [
        'Where you traveled to',
        'Who you went with',
        'What activities made it memorable',
        'And explain why it left a lasting impression',
      ],
    },
    {
      'topic': 'Describe a person who has inspired you to achieve a goal',
      'bullets': [
        'Who this person is',
        'How you know them',
        'What they accomplished that inspired you',
        'And explain how their influence helped you grow',
      ],
    },
  ];

  // Sunucudaki 2025-2026 konu havuzu (Item 4.1); yüklenemezse yerel liste kullanılır
  Map<String, dynamic>? _topicPool;
  String? _part1Guidance;
  List<String> _part3DiscussionQuestions = [];
  String? _part2TopicForPart3;
  String _candidateName = 'Student';
  final Random _random = Random();

  Future<void> _loadTopicPool() async {
    if (_topicPool != null && _topicPool!.isNotEmpty) return;
    final pool = await _apiService.getIeltsTopics();
    if (pool.isNotEmpty) _topicPool = pool;
  }

  void _pickPart1Category() {
    final categories = _topicPool?['part1_categories'];
    if (categories is List && categories.isNotEmpty) {
      final cat = categories[_random.nextInt(categories.length)];
      final questions = List<String>.from(cat['questions'] ?? const []);
      _part1Guidance =
          'Part 1 topic category: ${cat['category']}\n${questions.map((q) => '- $q').join('\n')}';
    }
  }

  /// Backend'e gönderilecek parça numarası (IELTS 1-3, TOEFL mülakat = 2)
  int get _apiPartNumber {
    if (_isToefl) return 2;
    switch (_currentPart) {
      case IeltsPart.part1:
        return 1;
      case IeltsPart.part2Prep:
      case IeltsPart.part2Speaking:
        return 2;
      case IeltsPart.part3:
      case IeltsPart.completed:
        return 3;
    }
  }

  /// O anki parçaya göre konu kartı / soru havuzu bilgisi
  String? get _currentGuidance {
    switch (_currentPart) {
      case IeltsPart.part1:
        return _isToefl ? _toeflTaskPrompt : _part1Guidance;
      case IeltsPart.part2Prep:
      case IeltsPart.part2Speaking:
        if (_currentTopicCard == null) return null;
        return [_currentTopicCard!, ..._topicCardBullets.map((b) => '- $b')].join('\n');
      case IeltsPart.part3:
        if (_isToefl) return _toeflTaskPrompt;
        if (_part3DiscussionQuestions.isEmpty) return _part2TopicForPart3;
        return 'Part 2 topic: ${_part2TopicForPart3 ?? ''}\n'
            'Part 3 discussion questions:\n${_part3DiscussionQuestions.map((q) => '- $q').join('\n')}';
      case IeltsPart.completed:
        return null;
    }
  }

  /// Sınavı başlat
  void startExam({String? candidateName}) {
    if (candidateName != null && candidateName.trim().isNotEmpty) {
      _candidateName = candidateName.trim();
    }
    _part1Guidance = null;
    _part3DiscussionQuestions = [];
    _part2TopicForPart3 = null;
    _toeflTaskPrompt = null;
    _listenItemNumbers.clear();
    _listenAccuracies.clear();
    _latestExamReport = null;
    _bandScore = null;
    _bandScoreFeedback = null;
    _currentTopicCard = null;
    _topicCardBullets = [];
    if (!_isToefl) {
      _loadTopicPool().then((_) {
        if (_currentPart == IeltsPart.part1) _pickPart1Category();
      });
    }
    _currentPart = IeltsPart.part1;
    _messages = [];
    _error = null;
    _isExamActive = true;
    _questionCount = 0;
    _elapsedSeconds = 0;

    // Part 1: IELTS 5 dk, TOEFL Listen and Repeat: 4 dk
    _startTimer(_isToefl ? 240 : 300);

    // Hoşgeldin mesajı
    String welcome;
    if (_isToefl) {
      _listenSentences = _toeflListenSets[_random.nextInt(_toeflListenSets.length)];
      welcome = "Welcome to your TOEFL iBT-style speaking practice (2026 format). Task 1: Listen and Repeat. "
          "You will hear $listenItemTotal sentences. Repeat each one exactly as you hear it.";
    } else {
      welcome = "Good morning. I'm your IELTS examiner, and I'll be conducting your speaking test today. "
          "Could you please tell me your full name?";
    }
    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content: welcome,
        timestamp: DateTime.now(),
      ),
    );
    if (_isToefl) _addListenItem();

    notifyListeners();
  }

  void _startTimer(int durationSeconds) {
    _timer?.cancel();
    _remainingSeconds = durationSeconds;

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
        if (_isToefl) {
          _transitionToToeflInterview();
        } else {
          _transitionToPart2();
        }
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

    // Rastgele bir konu kartı seç (önce sunucu havuzu, yoksa yerel liste)
    final remoteCards = _topicPool?['part2_cue_cards'];
    final List cards = (remoteCards is List && remoteCards.isNotEmpty) ? remoteCards : _topicCards;
    final card = cards[_random.nextInt(cards.length)];
    _currentTopicCard = card['topic'];
    _topicCardBullets = List<String>.from(card['bullets'] ?? const []);
    _part2TopicForPart3 = _currentTopicCard;
    _part3DiscussionQuestions = List<String>.from(card['part3_questions'] ?? const []);

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
    _startTimer(60);
    notifyListeners();
  }

  void _startPart2Speaking() {
    _currentPart = IeltsPart.part2Speaking;

    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content: "Your preparation time is over. Please begin speaking about the topic. "
            "Remember, you should speak for one to two minutes.",
        timestamp: DateTime.now(),
      ),
    );

    // 2 dakika konuşma süresi
    _startTimer(120);
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
        content: "Thank you. Now, let's move on to Part 3 of the test. "
            "I'd like to discuss some more general topics related to what you just talked about.",
        timestamp: DateTime.now(),
      ),
    );

    // 5 dakika
    _startTimer(300);
    notifyListeners();
  }

  Future<void> _completeExam() async {
    if (_currentPart == IeltsPart.completed) return;
    _currentPart = IeltsPart.completed;
    _timer?.cancel();
    _isExamActive = false;
    _isEvaluating = true;
    notifyListeners();

    // Konuşma geçmişinden band score ve karne raporu hesapla
    try {
      final history =
          _messages
              .where((msg) => msg.role == 'user' || msg.role == 'assistant')
              .map((msg) => msg.toJson())
              .toList();

      final report = await _apiService.evaluateAcademicExam(
        examType: _selectedExamType,
        conversationHistory: history,
        candidateName: _candidateName,
        listenRepeatAccuracy: _isToefl ? _listenAverage : null,
      );
      _latestExamReport = report;
      _bandScore = report.score;
      _bandScoreFeedback = report.feedback;
    } catch (e) {
      debugPrint('Exam score evaluation error: $e');
      _bandScore = _isToefl ? 4.0 : 6.5;
      _bandScoreFeedback = "Exam completed. Keep practicing to build academic fluency!";
    }

    _isEvaluating = false;
    if (_isDisposed) return;

    _addMessage(
      ConversationMessage(
        role: 'assistant',
        content:
            "Thank you very much. That's the end of your ${_isToefl ? 'TOEFL iBT-style speaking practice' : 'speaking exam'}. "
            "You did a great job! Your estimated score card and PDF report are now available.",
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void _addMessage(ConversationMessage message) {
    _messages.add(message);
    if (!_isDisposed) notifyListeners();
  }

  /// Kullanıcı mesajı gönder
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || !_isExamActive) return;

    // TOEFL Listen and Repeat: cevap cihazda puanlanır, sıradaki cümleye geçilir
    if (_isToefl && _currentPart == IeltsPart.part1) {
      _handleListenAnswer(userMessage.trim());
      return;
    }

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
    // Cevap beklenirken süre dolup bölüm değişebilir; o zaman sayaç ilerlemesin
    final partAtSend = _currentPart;
    // Bölümün son cevabıysa examiner yeni soru sormasın (hemen sonraki bölüme geçiliyor)
    final isLastTurn =
        (_currentPart == IeltsPart.part1 && _questionCount + 1 >= _part1Questions) ||
        (_currentPart == IeltsPart.part3 && _questionCount + 1 >= _part3Questions);

    try {
      // Konuşma geçmişini hazırla (backend yeni mesajı ayrıca ekliyor)
      final history =
          _messages
              .sublist(0, _messages.length - 1)
              .where((msg) => msg.role == 'user' || msg.role == 'assistant')
              .map((msg) => msg.toJson())
              .toList();

      Map<String, dynamic> response;
      if (_selectedExamType == AcademicExamType.ielts) {
        response = await _apiService.sendIeltsMessage(
          // Not: enum index'i (part2Speaking=2, part3=3) parça numarası değildir
          part: _apiPartNumber,
          userMessage: userMessage,
          conversationHistory: history,
          topicCard: _currentGuidance,
          isLastTurn: isLastTurn,
        );
      } else {
        response = await _apiService.sendExamMessage(
          examType: _selectedExamType.shortCode,
          taskIndex: _apiPartNumber,
          userMessage: userMessage,
          conversationHistory: history,
          // Mülakat senaryosu ve ilk soru backend'e gitsin
          taskPrompt: _currentGuidance,
          isLastTurn: isLastTurn,
        );
      }

      // Bu arada sınav bittiyse / ekrandan çıkıldıysa geç gelen cevabı ekleme
      if (_isDisposed || !_isExamActive) return;

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
      if (_currentPart == partAtSend) {
        _questionCount++;
        _checkPartTransition();
      }
    } catch (e) {
      _error = e.toString();
      if (_isDisposed) return;
      _addMessage(
        ConversationMessage(
          role: 'assistant',
          content: "Sorry, I'm having trouble. Please try again.",
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
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
    _latestExamReport = null;
    _toeflTaskPrompt = null;
    _listenItemNumbers.clear();
    _listenAccuracies.clear();
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
