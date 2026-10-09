import 'package:elo/models/models.dart';
import 'package:elo/providers/premium_provider.dart';
import 'package:elo/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ağa çıkmadan sınav akışını test etmek için sahte API
class FakeApiService extends ApiService {
  final List<Map<String, dynamic>> examCalls = [];
  AcademicExamType? evaluatedType;
  double? evaluatedListenAccuracy;

  @override
  Future<Map<String, dynamic>> sendExamMessage({
    required String examType,
    required int taskIndex,
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    String? taskPrompt,
    bool isLastTurn = false,
  }) async {
    examCalls.add({
      'examType': examType,
      'taskIndex': taskIndex,
      'taskPrompt': taskPrompt,
      'isLastTurn': isLastTurn,
    });
    return {
      'ai_message': 'Thank you. Could you give one more reason?',
      'feedback': 'Good structure.',
      'grammar_corrections': <String>[],
      'vocabulary_suggestions': <String>[],
    };
  }

  @override
  Future<Map<String, dynamic>> sendIeltsMessage({
    required int part,
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    String? topicCard,
    bool isLastTurn = false,
  }) async {
    examCalls.add({'examType': 'ielts', 'taskIndex': part, 'taskPrompt': topicCard});
    return {'ai_message': 'I see. Why is that?'};
  }

  @override
  Future<Map<String, dynamic>> getIeltsTopics() async => {};

  @override
  Future<ExamReport> evaluateAcademicExam({
    required AcademicExamType examType,
    required List<Map<String, dynamic>> conversationHistory,
    String candidateName = 'Student',
    double? listenRepeatAccuracy,
  }) async {
    evaluatedType = examType;
    evaluatedListenAccuracy = listenRepeatAccuracy;
    return ExamReport(
      examType: examType,
      score: 4.5,
      scoreDisplay: '4.5 / 6',
      cefrLevel: 'B2',
      feedback: 'Clear answers with relevant examples.',
      criteriaScores: {
        'Repeat Accuracy': 5.0,
        'Fluency & Pace': 4.5,
        'Vocabulary & Grammar': 4.0,
        'Elaboration': 4.5,
      },
      strengths: ['Clear reasons'],
      weaknesses: ['Limited range of linking words'],
      actionableTips: ['Practice the 60-second structure'],
      date: DateTime(2026, 10, 8),
      candidateName: candidateName,
    );
  }
}

/// Ses eklentilerinin (STT / TTS / audioplayers) kanallarını testte başarılı say
void mockPluginChannels() {
  const prefixes = ['plugin.csdcorp.com/', 'flutter_tts', 'xyz.luan/audioplayers'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler =
      (channel, handler, message) {
    if (prefixes.any(channel.startsWith)) {
      return Future.value(const StandardMethodCodec().encodeSuccessEnvelope(null));
    }
    return handler?.call(message);
  };
}

const phoneWidths = <double>[320, 360, 393, 440];

/// Sınav ekranındaki mesaj listesi (metin alanının kendi Scrollable'ı ile karışmasın)
final examList = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

Future<void> setScreen(WidgetTester tester, double width, {double height = 800}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, height * 3);
  addTearDown(tester.view.reset);
}


/// RevenueCat'e gitmeden premium / deneme durumunu taklit eden sağlayıcı
class FakePremiumProvider extends PremiumProvider {
  FakePremiumProvider({this.premium = false, this.trialDays});

  bool premium;
  int? trialDays;
  bool purchaseResult = true;
  final List<String> purchasedPlans = [];

  @override
  bool get isPremium => premium;
  @override
  bool get isLoading => false;
  @override
  int? get yearlyTrialDays => trialDays;
  @override
  bool get hasYearlyTrial => trialDays != null;
  @override
  String get yearlyPrice => '\$54.99';
  @override
  String get monthlyPrice => '\$6.99';

  @override
  Future<bool> purchaseSelectedPlan(String planId) async {
    purchasedPlans.add(planId);
    if (purchaseResult) {
      premium = true;
      notifyListeners();
    }
    return purchaseResult;
  }

  /// Satın alma sonrası durumu dışarıdan değiştirmek için
  void setPremium(bool value) {
    premium = value;
    notifyListeners();
  }
}
