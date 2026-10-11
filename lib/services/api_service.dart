import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Production URL - Render.com backend (Gemini AI only, stateless)
  static const String _productionUrl = 'https://elo-english.onrender.com';

  // Development mode control - Set to true if you are running the backend locally
  static const bool useLocalBackend = false;

  static String get baseUrl {
    // Release veya Profile modda (gerçek cihaz testi) production URL'i zorla
    // Çünkü profile modda simülatör değil gerçek cihaz kullanıyoruz ve localhost'a erişemeyiz.
    // kReleaseMode ve kProfileMode Flutter foundation'dan geliyor ve doğru çalışıyor.
    if (kReleaseMode || kProfileMode) {
      debugPrint('🌐 Using production URL: $_productionUrl');
      return _productionUrl;
    }

    // Yerel backend kapalıysa veya masaüstü modundaysa production kullan
    if (!useLocalBackend || (!Platform.isIOS && !Platform.isAndroid)) {
      return _productionUrl;
    }

    // Development modda localhost kullan
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000'; // Android Emulator
    } else {
      return 'http://localhost:8000'; // iOS Simulator / Desktop
    }
  }

  /// Render ücretsiz planda sunucu boşta kalınca uyuyor; ilk gerçek istekten
  /// önce uyandırmak için cevabı beklenmeyen bir istek atar.
  static void warmUp() {
    http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 70))
        .then((_) {}, onError: (_) {});
  }

  Future<List<Scenario>> getScenarios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scenarios'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Scenario.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load scenarios: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String scenarioId,
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    String userLevel = 'beginner',
    String? customSystemPrompt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/conversation'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'scenario': scenarioId,
          'user_message': userMessage,
          'conversation_history': conversationHistory,
          'user_level': userLevel,
          // Özel senaryolar (Item 2.4) sunucuda kayıtlı değil; prompt'u gönder
          'custom_system_prompt': customSystemPrompt,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<String> speechToText(String audioPath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/speech-to-text'),
      );
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'];
      } else {
        throw Exception('Failed to convert speech: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Speech recognition error: $e');
    }
  }

  Future<String> uploadAvatar(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/avatar'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      } else {
        throw Exception('Failed to upload avatar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  /// IELTS Speaking için özel mesaj gönderme
  Future<Map<String, dynamic>> sendIeltsMessage({
    required int part,
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    String? topicCard,
    bool isLastTurn = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ielts/conversation'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'part': part,
          'user_message': userMessage,
          'conversation_history': conversationHistory,
          'topic_card': topicCard,
          'is_last_turn': isLastTurn,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send IELTS message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// IELTS Speaking sınavını değerlendir ve band score al
  Future<Map<String, dynamic>> evaluateIeltsSpeaking(
    List<Map<String, dynamic>> conversationHistory,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ielts/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'conversation_history': conversationHistory}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to evaluate IELTS: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Canlı Yanıt Akışı (Streaming SSE - Item 2.3)
  Stream<Map<String, dynamic>> streamMessage({
    required String scenarioId,
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    String? customSystemPrompt,
    String userLevel = 'beginner',
  }) async* {
    final client = http.Client();
    // Akış ortasında hata olursa, yedek cevabı mevcut metnin sonuna eklememek için
    bool hasYieldedContent = false;
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/conversation/stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = json.encode({
        'scenario': scenarioId,
        'user_message': userMessage,
        'conversation_history': conversationHistory,
        'custom_system_prompt': customSystemPrompt,
        'user_level': userLevel,
      });

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 45));

      if (streamedResponse.statusCode == 200) {
        final stream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final Map<String, dynamic> data = json.decode(jsonStr);
                if (data['type'] == 'chunk') hasYieldedContent = true;
                yield data;
                if (data['type'] == 'done') break;
              } catch (_) {}
            }
          }
        }
      } else {
        // Fallback to non-streaming endpoint
        final regularResp = await sendMessage(
          scenarioId: scenarioId,
          userMessage: userMessage,
          conversationHistory: conversationHistory,
          userLevel: userLevel,
          customSystemPrompt: customSystemPrompt,
        );
        yield {'type': 'chunk', 'text': regularResp['ai_message']};
        yield {
          'type': 'feedback',
          'feedback': regularResp['feedback'],
          'grammar_corrections': regularResp['grammar_corrections'],
          'vocabulary_suggestions': regularResp['vocabulary_suggestions'],
        };
        yield {'type': 'done'};
      }
    } catch (e) {
      debugPrint('Streaming error: $e');
      if (hasYieldedContent) {
        // Cevabın bir kısmı zaten geldi; sadece akışı kapat
        yield {'type': 'done'};
        return;
      }
      // Graceful fallback
      final regularResp = await sendMessage(
        scenarioId: scenarioId,
        userMessage: userMessage,
        conversationHistory: conversationHistory,
        userLevel: userLevel,
        customSystemPrompt: customSystemPrompt,
      );
      yield {'type': 'chunk', 'text': regularResp['ai_message']};
      yield {
        'type': 'feedback',
        'feedback': regularResp['feedback'],
        'grammar_corrections': regularResp['grammar_corrections'],
        'vocabulary_suggestions': regularResp['vocabulary_suggestions'],
      };
      yield {'type': 'done'};
    } finally {
      client.close();
    }
  }

  /// Kendi Senaryonu Yarat (Item 2.4)
  Future<Scenario> createCustomScenario({
    required String userPrompt,
    String userLevel = 'intermediate',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scenarios/custom'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_prompt': userPrompt,
          'user_level': userLevel,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Scenario(
          id: data['id'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
          title: data['title'] ?? userPrompt,
          description: data['description'] ?? 'Custom practice scenario',
          difficulty: data['difficulty'] ?? 'intermediate',
          estimatedTime: data['estimated_time'] ?? 7,
          customSystemPrompt: data['system_prompt'],
          greeting: data['greeting'],
          isCustom: true,
        );
      } else {
        throw Exception('Failed to create scenario: ${response.statusCode}');
      }
    } catch (e) {
      // Local fallback if offline or backend error
      return Scenario(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        title: userPrompt.length > 25 ? '${userPrompt.substring(0, 25)}...' : userPrompt,
        description: 'Practice: $userPrompt',
        difficulty: 'intermediate',
        estimatedTime: 7,
        customSystemPrompt: 'You are roleplaying this scenario: $userPrompt. Speak naturally and keep answers short.',
        greeting: 'Hello! Let us practice together. What would you like to discuss first regarding this?',
        isCustom: true,
      );
    }
  }

  /// Telaffuz ve Vurgu Analizi (Item 2.2)
  Future<PronunciationResult> evaluatePronunciation({
    required String targetSentence,
    required String spokenText,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pronunciation/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'target_sentence': targetSentence,
          'spoken_text': spokenText,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return PronunciationResult.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Pronunciation evaluation error: $e');
    }

    // Heuristic fallback for offline / fast response
    final targetWords = targetSentence.split(RegExp(r'\s+'));
    final spokenLower = spokenText.toLowerCase();
    int matchCount = 0;
    final words = targetWords.map((w) {
      final clean = w.replaceAll(RegExp(r'[^\w]'), '');
      final isHit = clean.isNotEmpty && spokenLower.contains(clean.toLowerCase());
      if (isHit) matchCount++;
      return WordPronunciationScore(
        word: clean.isEmpty ? w : clean,
        ipa: '/${clean.toLowerCase()}/',
        score: isHit ? 90 : 58,
        status: isHit ? 'perfect' : 'needs_work',
        tip: !isHit ? 'Focus on tongue placement and steady airflow' : null,
      );
    }).toList();

    final ratio = targetWords.isNotEmpty ? matchCount / targetWords.length : 0.8;
    final score = (ratio * 100).toInt().clamp(55, 95);

    return PronunciationResult(
      overallScore: score,
      fluencyScore: (score - 4).clamp(50, 95),
      words: words,
      challengingSounds: ['/θ/', '/r/'],
      encouragement: score >= 80 ? 'Excellent articulation and rhythm!' : 'Good effort! Speak a bit slower for clearer sounds.',
    );
  }

  /// 2025-2026 sınav tarzı konu kartları havuzu (Item 4.1)
  Future<Map<String, dynamic>> getIeltsTopics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ielts/topics'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching topics: $e');
    }
    return {};
  }

  /// TOEFL iBT Speaking (Item 4.3)
  Future<Map<String, dynamic>> sendExamMessage({
    required String examType,
    required int taskIndex,
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    String? taskPrompt,
    bool isLastTurn = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exam/conversation'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'exam_type': examType,
          'task_index': taskIndex,
          'user_message': userMessage,
          'conversation_history': conversationHistory,
          'task_prompt': taskPrompt,
          'is_last_turn': isLastTurn,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed exam message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Exam error: $e');
    }
  }

  /// Genel Sınav Değerlendirmesi (Item 4.2 & 4.3)
  Future<ExamReport> evaluateAcademicExam({
    required AcademicExamType examType,
    required List<Map<String, dynamic>> conversationHistory,
    String candidateName = 'Student',
    double? listenRepeatAccuracy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exam/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'exam_type': examType.shortCode,
          'conversation_history': conversationHistory,
          // TOEFL Listen and Repeat doğruluğu cihazda ölçülüyor
          'listen_repeat_accuracy': listenRepeatAccuracy,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return ExamReport.fromJson(
          json.decode(response.body),
          type: examType,
          candidateName: candidateName,
        );
      }
    } catch (e) {
      debugPrint('Exam evaluation network error: $e');
    }

    // Default fallback
    return ExamReport(
      examType: examType,
      score: examType == AcademicExamType.ielts ? 6.5 : 4.0,
      scoreDisplay: examType == AcademicExamType.ielts ? 'Band 6.5 / 9.0' : '4.0 / 6',
      cefrLevel: 'B2',
      feedback: 'Good test performance with clear communicative ability and appropriate vocabulary.',
      criteriaScores: examType == AcademicExamType.ielts
          ? {
              'Fluency': 6.5,
              'Lexical Resource': 6.5,
              'Grammar': 6.0,
              'Pronunciation': 6.5,
            }
          : {
              'Repeat Accuracy': 4.0,
              'Fluency & Pace': 4.0,
              'Vocabulary & Grammar': 4.0,
              'Elaboration': 4.0,
            },
      strengths: ['Clear delivery', 'Good response structure'],
      weaknesses: ['Could use more complex transitions'],
      actionableTips: ['Practice speaking under strict time constraints to build fluency'],
      date: DateTime.now(),
      candidateName: candidateName,
    );
  }
}

