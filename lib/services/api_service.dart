import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Backend URL'inizi buraya yazın
  static const String baseUrl = 'http://localhost:8000';
  // iOS Simulator için localhost çalışır
  // Gerçek iOS cihaz için: 'http://YOUR_IP:8000'
  // Android Emulator için: 'http://10.0.2.2:8000'

  Future<List<Scenario>> getScenarios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scenarios'),
        headers: {'Content-Type': 'application/json'},
      );

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
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<UserProgress> getUserProgress(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/progress/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return UserProgress.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load progress: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> updateUserProgress({
    required String userId,
    int? totalMinutes,
    int? totalConversations,
    String? completedScenario,
    int? addedXp,
    String? displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/progress/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'total_minutes': totalMinutes,
          'total_conversations': totalConversations,
          'completed_scenario': completedScenario,
          'added_xp': addedXp,
          'display_name': displayName,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update progress: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leaderboard'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LeaderboardEntry.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load leaderboard: ${response.statusCode}');
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
        }),
      );

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
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to evaluate IELTS: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
