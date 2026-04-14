import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ScenarioProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Scenario> _scenarios = [];
  bool _isLoading = false;
  String? _error;

  List<Scenario> get scenarios => _scenarios;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const String _cacheKey = 'cached_scenarios';

  ScenarioProvider() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_cacheKey);
      
      if (cachedData != null) {
        final List<dynamic> decodedData = json.decode(cachedData);
        _scenarios = decodedData.map((json) => Scenario.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  Future<void> _saveToCache(List<Scenario> scenarios) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(
        scenarios.map((s) => s.toJson()).toList(),
      );
      await prefs.setString(_cacheKey, encodedData);
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }

  Future<void> loadScenarios({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final scenarios = await _apiService.getScenarios();
      _scenarios = scenarios;
      _isLoading = false;
      _error = null;
      
      // Save to local cache
      await _saveToCache(scenarios);
      
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      // Eğer hiç verimiz yoksa hatayı göster, varsa sessizce başarısız ol (mevcut veriyi koru)
      if (_scenarios.isEmpty) {
        _error = e.toString();
      }
      notifyListeners();
      rethrow;
    }
  }
}
