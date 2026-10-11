import 'dart:async';
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
  // Cloud TTS: her cümle kendi oynatıcısında çalar. audioplayers (iOS) bitiş
  // olayını gönderdikten SONRA oynatıcıyı release() ediyor; aynı oynatıcıya
  // hemen sonraki cümle yüklenirse bu geç release onu susturuyordu.
  AudioPlayer? _currentPlayer;

  // ============================================================================
  // ADIM 1 - GOOGLE CLOUD API KEY
  // Güvenlik gereği şifreniz artık kök dizindeki `.env` dosyasından okunuyor.
  // Bu alan boş kalırsa, uygulama eski bedava telefon sesini kullanmaya devam eder.
  String get _googleApiKey => dotenv.env['GOOGLE_TTS_API_KEY'] ?? ''; 
  // ============================================================================

  bool _initialized = false;
  bool _nativeReady = false;
  String _currentLanguage = 'en-US';
  VoidCallback? _onComplete;

  // Cümle kuyruğu (Streaming - Item 2.3): cümleler geldikçe sırayla seslendirilir
  final List<_SpeechItem> _queue = [];
  bool _isSpeaking = false;
  // stop()/speak() ile artar; eski (iptal edilmiş) async işleri geçersiz kılar
  int _generation = 0;
  int _fileCounter = 0;
  Completer<void>? _idleCompleter;

  bool get useCloudTts => _googleApiKey.isNotEmpty;

  /// Kuyrukta bekleyen veya çalan bir ses var mı
  bool get isSpeaking => _isSpeaking || _queue.isNotEmpty;

  TtsService._internal() {
    // Yerel TTS ses bitiş dinleyicisi
    _flutterTts.setCompletionHandler(_onUtteranceDone);
    _flutterTts.setErrorHandler((msg) {
      debugPrint('Native TTS error: $msg');
      _onUtteranceDone();
    });
  }

  /// Initialize TTS
  Future<void> initialize({String language = 'en-US'}) async {
    if (_initialized) {
      // Servis tekil (singleton); farklı ekranlar farklı aksan isteyebilir
      if (language != _currentLanguage) await setLanguage(language);
      return;
    }
    _currentLanguage = language;

    if (!useCloudTts) {
      await _ensureNativeReady();
    }

    _initialized = true;
  }

  Future<void> _ensureNativeReady() async {
    if (_nativeReady) return;
    _nativeReady = true;
    await _initNativeTts(_currentLanguage);
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

  /// Metni seslendirir; çalan sesi ve kuyruğu keser.
  /// Dönen Future, ses bittiğinde (veya kesildiğinde) tamamlanır.
  Future<void> speak(String text) async {
    await stop();
    enqueue(text);
    await _idleCompleter?.future;
  }

  /// Metni kuyruğun sonuna ekler; önceki cümleler bitince seslendirilir.
  /// Cloud TTS'te ses dosyası hemen hazırlanmaya başlar (cümleler arası boşluk olmasın diye).
  void enqueue(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _idleCompleter ??= Completer<void>();
    final prefetch = useCloudTts ? _synthesizeCloud(clean, _generation) : null;
    _queue.add(_SpeechItem(clean, prefetch));
    if (!_isSpeaking) _playNext();
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _isSpeaking = false;
      _completeIdle();
      _onComplete?.call();
      return;
    }

    _isSpeaking = true;
    final gen = _generation;
    final item = _queue.removeAt(0);

    try {
      if (!_initialized) await initialize(language: _currentLanguage);
      final path = item.cloudAudioPath != null ? await item.cloudAudioPath : null;
      if (gen != _generation) return; // Bu arada stop() çağrıldı

      if (path != null) {
        await _playFile(path, gen);
      } else {
        // Cloud kapalı ya da hata verdi: telefondaki sese düş (Fallback)
        await _ensureNativeReady();
        if (gen != _generation) return;
        await _flutterTts.speak(item.text);
      }
    } catch (e) {
      debugPrint('TTS playback error: $e');
      if (gen == _generation) _onUtteranceDone();
    }
  }

  Future<void> _playFile(String path, int gen) async {
    final player = AudioPlayer();
    _currentPlayer = player;
    player.onPlayerComplete.first.then((_) {
      if (_currentPlayer == player) _currentPlayer = null;
      player.dispose();
      if (gen == _generation) _onUtteranceDone();
    });
    try {
      await player.play(DeviceFileSource(path));
    } catch (_) {
      if (_currentPlayer == player) _currentPlayer = null;
      player.dispose();
      rethrow;
    }
  }

  void _onUtteranceDone() {
    if (!_isSpeaking) return;
    _playNext();
  }

  void _completeIdle() {
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// Google Cloud TTS REST API Çağrısı - MP3 dosya yolunu döndürür (hata olursa null)
  Future<String?> _synthesizeCloud(String text, int gen) async {
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

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "input": {"text": text},
              "voice": {"languageCode": _currentLanguage, "name": voiceName},
              "audioConfig": {"audioEncoding": "MP3"},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (gen != _generation) return null;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String audioContent = data['audioContent'];
        final Uint8List audioBytes = base64Decode(audioContent);

        // Sesi geçici bir dosyaya kaydet, AVPlayer uzantıya ihtiyaç duyar.
        // Kuyruktaki cümleler birbirinin dosyasını ezmesin diye dönen isimler.
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/tts_audio_${_fileCounter++ % 32}.mp3');
        await file.writeAsBytes(audioBytes);
        return file.path;
      }
      debugPrint('Cloud TTS Hatası: ${response.body}');
    } catch (e) {
      debugPrint('Cloud TTS Exception: $e');
    }
    return null;
  }

  /// Stop speaking (kuyruğu da temizler)
  Future<void> stop() async {
    _generation++;
    _queue.clear();
    _isSpeaking = false;
    _completeIdle();
    final player = _currentPlayer;
    _currentPlayer = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      player.dispose();
    }
    await _flutterTts.stop();
  }

  /// Reconfigure for a different language (e.g., 'en-GB' for IELTS)
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    if (_nativeReady) {
      await _flutterTts.setLanguage(language);
      if (Platform.isIOS) {
        await _selectBestNativeVoice(language);
      }
    }
  }

  /// Set completion handler (kuyruktaki tüm sesler bittiğinde çağrılır)
  void setCompletionHandler(VoidCallback? handler) {
    _onComplete = handler;
  }

  /// Telefon araması modu için hoparlör / ahize yönlendirmesi
  Future<void> setSpeakerphone(bool speakerOn) async {
    try {
      // Yeni oluşturulan her oynatıcı bu global ayarı kullanır
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          // Mikrofonla birlikte çalışabilmesi için playAndRecord; Bluetooth
          // kulaklık (AirPods vb.) bağlıysa ses oraya gitsin.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              if (speakerOn) AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.allowBluetoothA2DP,
            },
          ),
          // Android: medya kanalı hoparlör/kulaklığa, iletişim kanalı ahizeye gider
          android: speakerOn
              ? const AudioContextAndroid()
              : const AudioContextAndroid(
                  usageType: AndroidUsageType.voiceCommunication,
                  contentType: AndroidContentType.speech,
                ),
        ),
      );
    } catch (e) {
      debugPrint('Audio route error: $e');
    }
    if (Platform.isIOS && _nativeReady) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          if (speakerOn) IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.voiceChat,
      );
    }
  }

  /// Arama bittiğinde varsayılan ses yönlendirmesine dön
  Future<void> resetAudioRoute() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig().build());
    } catch (e) {
      debugPrint('Audio route reset error: $e');
    }
    if (Platform.isIOS && _nativeReady) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
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

class _SpeechItem {
  final String text;
  final Future<String?>? cloudAudioPath;

  _SpeechItem(this.text, this.cloudAudioPath);
}
