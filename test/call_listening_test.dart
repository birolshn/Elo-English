import 'dart:convert';

import 'package:elo/models/models.dart';
import 'package:elo/providers/conversation_provider.dart';
import 'package:elo/providers/premium_provider.dart';
import 'package:elo/screens/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'test_helpers.dart';

const _speechChannel = 'plugin.csdcorp.com/speech_to_text';
const _codec = StandardMethodCodec();
int listenCalls = 0;

void _mockChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler =
      (channel, handler, message) {
    if (channel == _speechChannel) {
      final call = _codec.decodeMethodCall(message);
      if (call.method == 'listen') listenCalls++;
      final ok = ['initialize', 'hasPermission', 'listen'].contains(call.method);
      return Future.value(_codec.encodeSuccessEnvelope(ok ? true : null));
    }
    if (['flutter_tts', 'xyz.luan/audioplayers'].any(channel.startsWith)) {
      return Future.value(_codec.encodeSuccessEnvelope(null));
    }
    return handler?.call(message);
  };
}

/// Telefondan gelen tanıma sonucunu taklit eder
Future<void> _recognized(WidgetTester tester, String words, {bool last = false}) async {
  final json = jsonEncode({
    'alternates': [
      {'recognizedWords': words, 'confidence': 0.9},
    ],
    'resultType': last ? 2 : 1,
  });
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _speechChannel,
    _codec.encodeMethodCall(MethodCall('textRecognition', json)),
    (_) {},
  );
}

List<String> _userTurns(ConversationProvider c) =>
    c.messages.where((m) => m.role == 'user').map((m) => m.content).toList();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '', isOptional: true);
    _mockChannels();
    listenCalls = 0;
  });

  /// Aramayı aç ve AI karşılaması bitmiş, sıra kullanıcıda olacak şekilde hazırla
  Future<ConversationProvider> pumpListeningCall(WidgetTester tester) async {
    await setScreen(tester, 393, height: 852);
    final conversation = ConversationProvider()
      ..setScenario(Scenario(
        id: 'restaurant',
        title: 'Ordering at a Restaurant',
        description: 'Order food',
        difficulty: 'beginner',
        estimatedTime: 0,
      ));
    addTearDown(conversation.stopTimer);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: conversation),
        ChangeNotifierProvider<PremiumProvider>(create: (_) => FakePremiumProvider(premium: true)),
      ],
      child: MaterialApp(home: CallScreen(scenario: conversation.currentScenario!)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    // Test ortamında TTS kanalı sahte; tamamlanma bildirimini elle yolla
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter_tts',
      _codec.encodeMethodCall(const MethodCall('speak.onComplete')),
      (_) {},
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Listening to you (Hands-Free)...'), findsOneWidget);
    expect(listenCalls, 1);
    return conversation;
  }

  /// Aramayı kapat (bir sonraki senaryo yeni bir aramayla başlar)
  Future<void> endCall(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await stt.SpeechToText().cancel();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  // Not: Senaryolar tek testte. audioplayers'ın global kapsamı bir kez hazırlanıyor
  // ve ayrı testlerde (ayrı sahte zaman ortamları) ikinci arama bu hazırlığı
  // beklerken takılıyor; gerçek uygulamada böyle bir ayrım yok.
  testWidgets('call mode keeps listening until the user has finished', (tester) async {
    final speech = stt.SpeechToText();

    // 1) Düşünmek için verilen kısa duraklamalar cümleyi bölmez
    var conversation = await pumpListeningCall(tester);
    await _recognized(tester, 'I would like');
    // Eski davranışta 1.6 sn sessizlik cevabı gönderiyordu
    await tester.pump(const Duration(seconds: 2));
    await _recognized(tester, 'I would like a table for two please');
    await tester.pump(const Duration(seconds: 2));
    expect(_userTurns(conversation), isEmpty);
    expect(find.text('Listening... tap the circle when done'), findsOneWidget);
    // Gerçekten sustu: sıra gönderilir
    await tester.pump(const Duration(seconds: 1));
    expect(_userTurns(conversation), ['I would like a table for two please']);
    await endCall(tester);

    // 2) iOS tanıma oturumunu kapatınca (≈1 dk sınırı) dinleme sürer, metin birleşir
    listenCalls = 0;
    conversation = await pumpListeningCall(tester);
    await _recognized(tester, 'First I want a salad', last: true);
    speech.statusListener!('done');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_userTurns(conversation), isEmpty);
    expect(listenCalls, 2, reason: 'yeni oturum açılmalı');
    await _recognized(tester, 'and then a soup');
    // Duraklamada gelen "no match" hatası da sırayı bitirmez
    speech.errorListener!(SpeechRecognitionError('error_no_match', true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_userTurns(conversation), isEmpty);
    expect(find.text('"First I want a salad and then a soup"'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(_userTurns(conversation), ['First I want a salad and then a soup']);
    await endCall(tester);

    // 3) Daireye dokunmak beklemeden gönderir
    listenCalls = 0;
    conversation = await pumpListeningCall(tester);
    await _recognized(tester, 'Can I see the menu');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.mic_rounded).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_userTurns(conversation), ['Can I see the menu']);
    await endCall(tester);

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(minutes: 11));
  });
}
