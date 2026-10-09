import 'package:elo/models/models.dart';
import 'package:elo/providers/ielts_provider.dart';
import 'package:elo/providers/scenario_provider.dart';
import 'package:elo/screens/ielts_exam_screen.dart';
import 'package:elo/widgets/custom_scenario_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elo/providers/premium_provider.dart';
import 'test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    mockPluginChannels();
  });

  group('Create with AI sheet', () {
    for (final width in phoneWidths) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('no overflow at ${width.toInt()}pt, text x$scale', (tester) async {
          await setScreen(tester, width);
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => ScenarioProvider(),
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
                  child: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: CustomScenarioDialog())),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final label in ['Beginner', 'Intermediate', 'Advanced']) {
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  Widget examApp(IeltsProvider provider) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider<PremiumProvider>(create: (_) => FakePremiumProvider(premium: true)),
        ],
        child: const MaterialApp(home: IeltsExamScreen()),
      );

  group('Exam start screen', () {
    for (final type in AcademicExamType.values) {
      for (final width in phoneWidths) {
        testWidgets('${type.shortCode} start screen fits ${width.toInt()}pt', (tester) async {
          await setScreen(tester, width);
          final provider = IeltsProvider(apiService: FakeApiService())..setExamType(type);
          await tester.pumpWidget(examApp(provider));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(type.displayName), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  test('Listen and Repeat accuracy respects word order and extra words', () {
    const target = 'The library opens at eight.';
    expect(IeltsProvider.repeatAccuracy(target, 'the library opens at eight'), 100);
    expect(IeltsProvider.repeatAccuracy(target, ''), 0);
    expect(IeltsProvider.repeatAccuracy(target, 'library the opens'), lessThan(70));
    expect(IeltsProvider.repeatAccuracy(target, 'the library opens at eight o clock today'), lessThan(100));
  });

  testWidgets('TOEFL 2026 flow: Listen and Repeat + interview, 1-6 band score', (tester) async {
    await setScreen(tester, 320, height: 640);
    final api = FakeApiService();
    final provider = IeltsProvider(apiService: api)..setExamType(AcademicExamType.toefl);
    await tester.pumpWidget(examApp(provider));
    await tester.pump();

    provider.startExam(candidateName: 'Test User');
    await tester.pump();
    expect(provider.partTitle, 'Task 1 - Listen and Repeat');
    expect(provider.messages.first.content, contains('2026 format'));
    // Cümle cevaplanana kadar gizli
    final firstSentence = provider.messages.last.content;
    await tester.scrollUntilVisible(find.text('Listen and repeat · 1/7'), 200, scrollable: examList);
    expect(find.text('Listen and repeat · 1/7'), findsOneWidget);
    expect(find.text(firstSentence), findsNothing);

    // 7 cümle: ilki birebir, diğerleri eksik tekrar
    for (var i = 0; i < IeltsProvider.listenItemTotal; i++) {
      final sentence = provider.messages.last.content;
      final words = sentence.split(' ');
      await provider.sendMessage(i == 0 ? sentence : words.take(words.length - 1).join(' '));
      await tester.pump();
    }
    // Backend'e gitmeden cihazda puanlandı
    expect(api.examCalls, isEmpty);
    expect(provider.currentPart, IeltsPart.part3);
    expect(provider.partTitle, 'Task 2 - Take an Interview');
    expect(provider.messages.last.content, contains('Take an Interview'));
    // İlk cevap cümlenin aynısı: metin hem cümle balonunda hem kullanıcı balonunda görünür
    await tester.scrollUntilVisible(find.text('Accuracy: 100%'), -200, scrollable: examList);
    expect(find.text(firstSentence), findsNWidgets(2));
    expect(find.text('Accuracy: 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 4; i++) {
      await provider.sendMessage('I usually study in the library in the evening. $i');
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(provider.currentPart, IeltsPart.completed);
    expect(api.evaluatedType, AcademicExamType.toefl);
    expect(api.evaluatedListenAccuracy, isNotNull);
    expect(api.evaluatedListenAccuracy!, inExclusiveRange(80, 100));
    expect(api.examCalls.every((c) => c['examType'] == 'toefl' && c['taskIndex'] == 2), isTrue);
    expect(api.examCalls.map((c) => c['isLastTurn']).toList(), [false, false, false, true]);
    expect(api.examCalls.first['taskPrompt'], contains('Interview scenario'));

    await tester.scrollUntilVisible(find.text('TOEFL iBT Speaking Estimated Score'), 200, scrollable: examList);
    expect(find.text('4.5 / 6'), findsOneWidget);
    expect(find.textContaining('CEFR B2 · ≈ 23-24'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Start New Exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start New Exam'));
    await tester.pump();
    expect(find.text('Select Exam Format'), findsOneWidget);
  });

  test('TOEFL band maps to the former 0-30 speaking range', () {
    expect(toeflSpeakingLegacyRange(6), '28-30');
    expect(toeflSpeakingLegacyRange(4.5), '23-24');
    expect(toeflSpeakingLegacyRange(1), '0-4');
  });
}
