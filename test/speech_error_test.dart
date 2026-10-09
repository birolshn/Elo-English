import 'package:elo/models/models.dart';
import 'package:elo/providers/ielts_provider.dart';
import 'package:elo/providers/premium_provider.dart';
import 'package:elo/screens/ielts_exam_screen.dart';
import 'package:elo/services/speech_error_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'test_helpers.dart';

/// Konuşma tanıma kanalını taklit eder; kaç kez listen çağrıldığını sayar
int listenCalls = 0;

void _mockSpeechChannel() {
  const codec = StandardMethodCodec();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler =
      (channel, handler, message) {
    if (channel == 'plugin.csdcorp.com/speech_to_text') {
      final call = codec.decodeMethodCall(message);
      if (call.method == 'listen') listenCalls++;
      final result = (call.method == 'initialize' || call.method == 'hasPermission' || call.method == 'listen')
          ? true
          : null;
      return Future.value(codec.encodeSuccessEnvelope(result));
    }
    if (['flutter_tts', 'xyz.luan/audioplayers'].any(channel.startsWith)) {
      return Future.value(codec.encodeSuccessEnvelope(null));
    }
    return handler?.call(message);
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    _mockSpeechChannel();
    listenCalls = 0;
  });

  test('only transient speech errors are retried', () {
    expect(SpeechErrorHelper.isFatal('error_no_match'), isFalse);
    expect(SpeechErrorHelper.isFatal('error_speech_timeout'), isFalse);
    // iOS 26.4 simülatörü: "Failed to initialize recognizer"
    expect(SpeechErrorHelper.isFatal('error_unknown (300)'), isTrue);
    expect(SpeechErrorHelper.isFatal('error_listen_failed'), isTrue);
  });

  Future<IeltsProvider> pumpToefl(WidgetTester tester) async {
    await setScreen(tester, 393, height: 852);
    final exam = IeltsProvider(apiService: FakeApiService())..setExamType(AcademicExamType.toefl);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: exam),
        ChangeNotifierProvider<PremiumProvider>(create: (_) => FakePremiumProvider(premium: true)),
      ],
      child: const MaterialApp(home: IeltsExamScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    exam.startExam();
    await tester.pump(const Duration(milliseconds: 300));
    return exam;
  }

  /// Sınav zamanlayıcısını ve snackbar zamanlayıcısını kapat (bekleyen Timer kalmasın)
  Future<void> finish(WidgetTester tester, IeltsProvider exam) async {
    exam.stopExam();
    // speech_to_text, listenFor/pauseFor için Dart tarafında zamanlayıcı tutuyor
    await stt.SpeechToText().cancel();
    // Ekran kapanırken stop() son sonuç için kısa bir zamanlayıcı kurar; onu da bekle
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 11));
  }

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('recognizer failure (error 300) stops the restart loop and offers typing', (tester) async {
    final exam = await pumpToefl(tester);
    await tapMic(tester);
    expect(listenCalls, 1);

    // Simülatördeki sıra: listening -> done -> error_unknown (300)
    final speech = stt.SpeechToText();
    speech.statusListener!('listening');
    speech.statusListener!('done');
    speech.errorListener!(SpeechRecognitionError('error_unknown (300)', true));
    await tester.pump(const Duration(milliseconds: 500));

    // Yeniden dinleme başlamadı, kullanıcı bilgilendirildi
    expect(listenCalls, 1);
    expect(find.text(SpeechErrorHelper.unavailableMessage), findsOneWidget);

    // "Type instead" -> klavye; yazılan cevap Listen and Repeat olarak puanlanır
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
    await tester.pump(const Duration(seconds: 1));
    final sentence = exam.messages.last.content;
    await tester.enterText(find.byType(TextField), sentence);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 300));
    expect(exam.listenAccuracy(exam.messages[1]), 100);
    expect(tester.takeException(), isNull);
    await finish(tester, exam);
  });

  testWidgets('sessions that end instantly without any error are not retried forever', (tester) async {
    final exam = await pumpToefl(tester);
    await tapMic(tester);
    final speech = stt.SpeechToText();
    for (var i = 0; i < 5; i++) {
      speech.statusListener!('listening');
      speech.statusListener!('done');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    // 1 kullanıcı başlatması + en fazla 2 otomatik yeniden deneme
    expect(listenCalls, lessThanOrEqualTo(3));
    expect(find.text(SpeechErrorHelper.unavailableMessage), findsOneWidget);
    await finish(tester, exam);
  });

  testWidgets('a "no match" pause keeps listening (normal speech gaps)', (tester) async {
    final exam = await pumpToefl(tester);
    await tapMic(tester);
    final speech = stt.SpeechToText();
    speech.statusListener!('listening');
    await tester.pump(const Duration(seconds: 2)); // normal süreli bir oturum
    speech.statusListener!('done');
    speech.errorListener!(SpeechRecognitionError('error_no_match', true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(listenCalls, 2);
    expect(find.text(SpeechErrorHelper.unavailableMessage), findsNothing);
    await finish(tester, exam);
  });
}
