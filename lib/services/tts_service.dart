import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized TTS service supporting both Google Cloud TTS and native device TTS.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ============================================================================
  // ADIM 1 - GOOGLE CLOUD API KEY
  // Güvenlik gereği şifreniz artık kök dizindeki `.env` dosyasından okunuyor.
  // Bu alan boş kalırsa, uygulama eski bedava telefon sesini kullanmaya devam eder.
  String get _googleApiKey => dotenv.env['GOOGLE_TTS_API_KEY'] ?? ''; 
  // ============================================================================

  bool _initialized = false;
  String _currentLanguage = 'en-US';
  VoidCallback? _onComplete;

  bool get useCloudTts => _googleApiKey.isNotEmpty;

  TtsService._internal() {
    // Cloud TTS ses bitiş dinleyicisi
    _audioPlayer.onPlayerComplete.listen((event) {
      if (_onComplete != null) _onComplete!();
    });
    // Yerel TTS ses bitiş dinleyicisi
    _flutterTts.setCompletionHandler(() {
      if (_onComplete != null) _onComplete!();
    });
  }

  /// Initialize TTS
  Future<void> initialize({String language = 'en-US'}) async {
    if (_initialized) return;
    _currentLanguage = language;

    if (!useCloudTts) {
      await _initNativeTts(language);
    }

    _initialized = true;
  }

  /// Native (Device) TTS Ayarları
  Future<void> _initNativeTts(String language) async {
    await _flutterTts.setLanguage(language);
    await _flutterTts.setVolume(1.0);

    if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
      await _selectBestNativeVoice(language);
    }

    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setPitch(0.95);
  }

  /// Speak text (Cloud veya Native seçer)
  Future<void> speak(String text) async {
    if (!_initialized) await initialize(language: _currentLanguage);

    if (useCloudTts) {
      await _speakWithCloudTts(text);
    } else {
      await _flutterTts.speak(text);
    }
  }

  /// Google Cloud TTS REST API Çağrısı
  Future<void> _speakWithCloudTts(String text) async {
    try {
      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_googleApiKey',
      );

      // Seslerin daha hızlı gelmesi için Neural2 kullanıyoruz. 
      // H ve B varyasyonları daha doğal tonlamalara sahiptir.
      String voiceName =
          _currentLanguage.contains('GB')
              ? 'en-GB-Neural2-B'
              : 'en-US-Neural2-H';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"text": text},
          "voice": {"languageCode": _currentLanguage, "name": voiceName},
          "audioConfig": {"audioEncoding": "MP3"},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String audioContent = data['audioContent'];
        final Uint8List audioBytes = base64Decode(audioContent);

        // Sesi geçici bir dosyaya kaydet, AVPlayer uzantıya ihtiyaç duyar
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/tts_audio.mp3');
        await file.writeAsBytes(audioBytes);

        // Sesi audioplayers paketi ile oynat
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        debugPrint('Cloud TTS Hatası: ${response.body}');
        // Hata olursa (örneğin limit biterse) telefondaki sese düş (Fallback)
        await _flutterTts.speak(text);
      }
    } catch (e) {
      debugPrint('Cloud TTS Exception: $e');
      await _flutterTts.speak(text);
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (useCloudTts) {
      await _audioPlayer.stop();
    }
    await _flutterTts.stop();
  }

  /// Reconfigure for a different language (e.g., 'en-GB' for IELTS)
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    if (!useCloudTts) {
      await _flutterTts.setLanguage(language);
      if (Platform.isIOS) {
        await _selectBestNativeVoice(language);
      }
    }
  }

  /// Set completion handler
  void setCompletionHandler(VoidCallback handler) {
    _onComplete = handler;
  }

  /// Eski Yerel TTS Ses Seçimi (Sadece Cloud API Key boşsa çalışır)
  Future<void> _selectBestNativeVoice(String language) async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null) return;

      final voiceList = List<Map<dynamic, dynamic>>.from(voices);
      final langPrefix = language.split('-').first.toLowerCase();

      final matchingVoices =
          voiceList.where((v) {
            final locale =
                (v['locale'] ?? v['name'] ?? '').toString().toLowerCase();
            return locale.contains(langPrefix);
          }).toList();

      if (matchingVoices.isEmpty) return;

      const preferredVoices = [
        'Siri Voice 4',
        'Siri Voice 3',
        'Ava (Premium)',
        'Samantha (Enhanced)',
      ];

      for (final preferred in preferredVoices) {
        final match = matchingVoices.where(
          (v) => v['name'].toString() == preferred,
        );
        if (match.isNotEmpty) {
          await _flutterTts.setVoice({
            'name': match.first['name'].toString(),
            'locale': match.first['locale'].toString(),
          });
          return;
        }
      }

      final enhanced = matchingVoices.where((v) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        return name.contains('enhanced') || name.contains('premium');
      });

      if (enhanced.isNotEmpty) {
        await _flutterTts.setVoice({
          'name': enhanced.first['name'].toString(),
          'locale': enhanced.first['locale'].toString(),
        });
      }
    } catch (_) {}
  }
}
