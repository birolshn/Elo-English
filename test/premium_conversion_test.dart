import 'package:elo/models/models.dart';
import 'package:elo/providers/conversation_provider.dart';
import 'package:elo/providers/ielts_provider.dart';
import 'package:elo/providers/premium_provider.dart';
import 'package:elo/screens/call_screen.dart';
import 'package:elo/screens/ielts_exam_screen.dart';
import 'package:elo/screens/onboarding_screen.dart';
import 'package:elo/screens/trial_offer_screen.dart';
import 'package:elo/services/premium_gate_service.dart';
import 'package:elo/widgets/premium_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Sürekli dönen animasyonlu ekranlar için (pumpAndSettle hiç bitmez)
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    mockPluginChannels();
  });

  // ─── 1. Ücretsiz deneme ────────────────────────────────────────────────

  group('Free trial detection', () {
    test('reads the trial length from store products', () {
      // iOS: ücretsiz intro offer
      expect(
        PremiumProvider.freeTrialDaysFrom(
          intro: const IntroductoryPrice(0, 'Free', 'P1W', 1, PeriodUnit.week, 1),
        ),
        7,
      );
      expect(
        PremiumProvider.freeTrialDaysFrom(
          intro: const IntroductoryPrice(0, 'Free', 'P3D', 1, PeriodUnit.day, 3),
        ),
        3,
      );
      // Ücretli intro fiyat deneme değildir
      expect(
        PremiumProvider.freeTrialDaysFrom(
          intro: const IntroductoryPrice(1.99, '\$1.99', 'P1M', 1, PeriodUnit.month, 1),
        ),
        isNull,
      );
      // Android: base plan'daki ücretsiz faz
      const freePhase = PricingPhase(Period(PeriodUnit.week, 1, 'P1W'), null, 1, Price('Free', 0, 'USD'), null);
      const option = SubscriptionOption(
          'trial', 'yearly:base', 'yearly', [freePhase], [], false, null, false, null, freePhase, null, null, null);
      expect(PremiumProvider.freeTrialDaysFrom(option: option), 7);
      expect(PremiumProvider.freeTrialDaysFrom(), isNull);
    });

    Widget offerApp(FakePremiumProvider premium, {required ValueChanged<bool> onResult}) {
      return ChangeNotifierProvider<PremiumProvider>.value(
        value: premium,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => onResult(await TrialOfferScreen.show(context)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final width in phoneWidths) {
      testWidgets('trial offer screen fits ${width.toInt()}pt and starts the yearly trial', (tester) async {
        await setScreen(tester, width, height: 760);
        final premium = FakePremiumProvider(trialDays: 7);
        bool? result;
        await tester.pumpWidget(offerApp(premium, onResult: (r) => result = r));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Try Premium free for 7 days'), findsOneWidget);
        expect(find.text('Day 5'), findsOneWidget); // hatırlatma: bitişten 2 gün önce
        expect(find.text('Free for 7 days, then \$54.99/year. Cancel anytime.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Start 7-Day Free Trial'));
        await tester.pumpAndSettle();
        expect(premium.purchasedPlans, ['yearly']);
        expect(result, isTrue);
        expect(find.byType(TrialOfferScreen), findsNothing);
      });
    }

    Widget onboardingApp(FakePremiumProvider premium, VoidCallback onComplete) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ConversationProvider()),
            ChangeNotifierProvider<PremiumProvider>.value(value: premium),
          ],
          child: MaterialApp(home: OnboardingScreen(onComplete: onComplete)),
        );

    testWidgets('onboarding ends with the trial offer, then completes', (tester) async {
      await setScreen(tester, 393, height: 852);
      var completed = false;
      await tester.pumpWidget(onboardingApp(FakePremiumProvider(trialDays: 7), () => completed = true));
      await _pumpFrames(tester);

      await tester.tap(find.text('Skip'));
      await _pumpFrames(tester);
      expect(find.byType(TrialOfferScreen), findsOneWidget);
      expect(completed, isFalse);

      await tester.tap(find.text('Continue with free plan'));
      await _pumpFrames(tester);
      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets('premium users skip the trial offer in onboarding', (tester) async {
      await setScreen(tester, 393, height: 852);
      var completed = false;
      await tester.pumpWidget(onboardingApp(FakePremiumProvider(premium: true), () => completed = true));
      await _pumpFrames(tester);
      await tester.tap(find.text('Skip'));
      await _pumpFrames(tester);
      expect(find.byType(TrialOfferScreen), findsNothing);
      expect(completed, isTrue);
    });

    testWidgets('without a store trial the offer never promises one', (tester) async {
      await setScreen(tester, 393);
      final premium = FakePremiumProvider(trialDays: null);
      bool? result;
      await tester.pumpWidget(offerApp(premium, onResult: (r) => result = r));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Elo English Premium'), findsOneWidget);
      expect(find.text('Get Premium - \$54.99/year'), findsOneWidget);
      expect(find.textContaining('free trial', findRichText: true), findsNothing);
      expect(find.textContaining('Free for'), findsNothing);

      await tester.tap(find.text('Continue with free plan'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(premium.purchasedPlans, isEmpty);
    });

    testWidgets('paywall shows the trial only for the yearly plan', (tester) async {
      await setScreen(tester, 393, height: 900);
      final premium = FakePremiumProvider(trialDays: 7);
      await tester.pumpWidget(ChangeNotifierProvider<PremiumProvider>.value(
        value: premium,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showPremiumPopup(context, triggerContext: 'exam_report'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Score Report'), findsOneWidget);
      expect(find.text('Start 7-Day Free Trial'), findsOneWidget);
      expect(find.text('7-day free trial'), findsOneWidget);

      await tester.ensureVisible(find.text('Premium 1 Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Premium 1 Month'));
      await tester.pumpAndSettle();
      expect(find.text('Start 7-Day Free Trial'), findsNothing);
      expect(find.text('Get Premium - \$6.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ─── 2. Haftada 1 ücretsiz sınav, kilitli rapor ────────────────────────

  group('Weekly free mock test', () {
    test('quota resets after 7 days', () async {
      var now = DateTime(2026, 10, 9, 10);
      final gate = PremiumGateService(clock: () => now);
      expect(await gate.canStartFreeExam(), isTrue);
      await gate.markFreeExamUsed();
      expect(await gate.canStartFreeExam(), isFalse);
      expect(await gate.nextFreeExamAt(), DateTime(2026, 10, 16, 10));
      now = DateTime(2026, 10, 16, 10, 1);
      expect(await gate.canStartFreeExam(), isTrue);
    });

    Widget examApp(IeltsProvider exam, FakePremiumProvider premium) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: exam),
            ChangeNotifierProvider<PremiumProvider>.value(value: premium),
          ],
          child: const MaterialApp(home: IeltsExamScreen()),
        );

    testWidgets('free user gets one test, then the paywall', (tester) async {
      await setScreen(tester, 360, height: 1200);
      final exam = IeltsProvider(apiService: FakeApiService());
      final premium = FakePremiumProvider();
      await tester.pumpWidget(examApp(exam, premium));
      await tester.pumpAndSettle();

      expect(find.text('Your free mock test this week is ready'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Exam'));
      await tester.pumpAndSettle();
      expect(exam.isExamActive, isTrue);
      expect(await PremiumGateService().canStartFreeExam(), isFalse);

      // Başlangıç ekranına dön: hak kullanıldı
      exam.clearExam();
      await tester.pumpAndSettle();
      expect(find.text('Free mock test used this week'), findsOneWidget);
      expect(find.textContaining('Next free test in 7 days'), findsOneWidget);

      await tester.ensureVisible(find.text('Start Exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Exam'));
      await tester.pumpAndSettle();
      expect(exam.isExamActive, isFalse);
      expect(find.text('IELTS & TOEFL Speaking is Premium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('free results show the score but lock criteria, tips and PDF until purchase', (tester) async {
      await setScreen(tester, 360, height: 760);
      final exam = IeltsProvider(apiService: FakeApiService())..setExamType(AcademicExamType.toefl);
      final premium = FakePremiumProvider(trialDays: 7);
      await tester.pumpWidget(examApp(exam, premium));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start Exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Exam'));
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < IeltsProvider.listenItemTotal; i++) {
        await exam.sendMessage(exam.messages.last.content);
        await tester.pump();
      }
      for (var i = 0; i < 4; i++) {
        await exam.sendMessage('I usually study in the library. $i');
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(exam.currentPart, IeltsPart.completed);

      // Skor görünür (merak), detaylar kilitli
      await tester.scrollUntilVisible(find.text('4.5 / 6'), 200, scrollable: examList);
      await tester.ensureVisible(find.text('Unlock PDF Exam Report'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock Full Report'), findsNWidgets(2));
      expect(find.text('5.0'), findsNothing); // gerçek kriter puanı çizilmiyor
      expect(find.text('Practice the 60-second structure'), findsNothing);
      expect(find.text('How to reach 5.0 / 6'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Unlock PDF Exam Report'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock Your Full Score Report'), findsOneWidget);

      // Deneme başlatıldı -> kilitler anında açılır
      await tester.tap(find.text('Start 7-Day Free Trial'));
      await tester.pumpAndSettle();
      expect(premium.purchasedPlans, ['yearly']);
      expect(find.text('Unlock Full Report'), findsNothing);
      await tester.ensureVisible(find.text('Download / Share PDF Exam Report'));
      await tester.pumpAndSettle();
      expect(find.text('Practice the 60-second structure'), findsOneWidget);
      await tester.ensureVisible(find.text('Estimated Score by Criteria'));
      await tester.pumpAndSettle();
      expect(find.text('5.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ─── 3. Bağlamsal paywall'lar ───────────────────────────────────────────

  group('Call mode free minutes', () {
    test('3 free minutes per day, reset the next day', () async {
      var now = DateTime(2026, 10, 9, 21);
      final gate = PremiumGateService(clock: () => now);
      expect(await gate.remainingFreeCallSeconds(), 180);
      await gate.addCallSeconds(100);
      expect(await gate.remainingFreeCallSeconds(), 80);
      await gate.addCallSeconds(500);
      expect(await gate.remainingFreeCallSeconds(), 0);
      now = DateTime(2026, 10, 10, 8);
      expect(await gate.remainingFreeCallSeconds(), 180);
    });

    Future<ConversationProvider> pumpCall(WidgetTester tester, FakePremiumProvider premium) async {
      await setScreen(tester, 393, height: 852);
      final conversation = ConversationProvider()
        ..setScenario(Scenario(
          id: 'small_talk',
          title: 'Small Talk',
          description: 'Chat',
          difficulty: 'beginner',
          estimatedTime: 0,
        ));
      addTearDown(conversation.stopTimer);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: conversation),
          ChangeNotifierProvider<PremiumProvider>.value(value: premium),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CallScreen(scenario: conversation.currentScenario!),
                )),
                child: const Text('call'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('call'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      return conversation;
    }

    testWidgets('call ends with the paywall when the free minutes run out', (tester) async {
      // Bugün 178 sn kullanılmış: 2 sn kaldı
      await PremiumGateService().addCallSeconds(178);
      await pumpCall(tester, FakePremiumProvider());
      expect(find.text('Free: 0:02 left today'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text("Today's Free Call Minutes Are Up"), findsOneWidget);
      expect(await PremiumGateService().remainingFreeCallSeconds(), 0);

      await tester.tap(find.text('Maybe Later'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CallScreen), findsNothing);
    });

    testWidgets('premium users have no call limit', (tester) async {
      await PremiumGateService().addCallSeconds(500);
      await pumpCall(tester, FakePremiumProvider(premium: true));
      expect(find.textContaining('left today'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text("Today's Free Call Minutes Are Up"), findsNothing);
      expect(find.byType(CallScreen), findsOneWidget);
      // Ekranı kapat (zamanlayıcılar temizlensin)
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  group('Great session offer', () {
    test('shown at most once per day', () async {
      var now = DateTime(2026, 10, 9, 12);
      final gate = PremiumGateService(clock: () => now);
      expect(await gate.shouldShowSessionWin(), isTrue);
      await gate.markSessionWinShown();
      expect(await gate.shouldShowSessionWin(), isFalse);
      now = DateTime(2026, 10, 10, 9);
      expect(await gate.shouldShowSessionWin(), isTrue);
    });

    testWidgets('sheet shows session stats and leads to the paywall', (tester) async {
      await setScreen(tester, 360, height: 800);
      final premium = FakePremiumProvider(trialDays: 7);
      await tester.pumpWidget(ChangeNotifierProvider<PremiumProvider>.value(
        value: premium,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showSessionWinSheet(context, userMessages: 9, minutes: 4, corrections: 2),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Great session!'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Try Premium Free for 7 Days'));
      await tester.pumpAndSettle();
      expect(find.text('Great Session!'), findsOneWidget); // paywall başlığı
      expect(find.text('Start 7-Day Free Trial'), findsOneWidget);
    });
  });
}
