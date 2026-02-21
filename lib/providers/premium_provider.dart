import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class PremiumProvider with ChangeNotifier {
  PremiumStatus _status = PremiumStatus();
  bool _isLoading = false;

  PremiumStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isPremium => _status.isActive;

  PremiumProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    // Ülke tespiti
    final isTurkish = _detectTurkishUser();
    final priceDisplay = isTurkish ? '249 TL/ay' : '\$9.99/mo';

    // Kayıtlı premium durumunu yükle
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium') ?? false;
    final expiryTimestamp = prefs.getInt('premium_expiry');
    final subscriptionType = prefs.getString('subscription_type');

    DateTime? expiryDate;
    if (expiryTimestamp != null) {
      expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
    }

    _status = PremiumStatus(
      isPremium: isPremium,
      expiryDate: expiryDate,
      subscriptionType: subscriptionType,
      priceDisplay: priceDisplay,
      isTurkishUser: isTurkish,
    );

    _isLoading = false;
    notifyListeners();
  }

  bool _detectTurkishUser() {
    try {
      final locale = Platform.localeName;
      return locale.toLowerCase().contains('tr');
    } catch (e) {
      return false;
    }
  }

  String get monthlyPrice => _status.isTurkishUser ? '249 TL' : '\$9.99';
  String get yearlyPrice => _status.isTurkishUser ? '1.999 TL' : '\$99.99';

  /// Premium satın alma (simülasyon - gerçek uygulamada RevenueCat kullanılacak)
  Future<bool> purchasePremium({String type = 'monthly'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simülasyon: gerçek uygulamada burada RevenueCat/Play Billing çağrısı yapılır
      await Future.delayed(const Duration(seconds: 1));

      // Başarılı satın alma simülasyonu
      final expiryDate =
          type == 'yearly'
              ? DateTime.now().add(const Duration(days: 365))
              : DateTime.now().add(const Duration(days: 30));

      // Kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
      await prefs.setInt('premium_expiry', expiryDate.millisecondsSinceEpoch);
      await prefs.setString('subscription_type', type);

      _status = _status.copyWith(
        isPremium: true,
        expiryDate: expiryDate,
        subscriptionType: type,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Premium durumunu kontrol et
  Future<void> checkPremiumStatus() async {
    await _initialize();
  }

  /// Premium'u iptal et (test için)
  Future<void> cancelPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_premium');
    await prefs.remove('premium_expiry');
    await prefs.remove('subscription_type');

    _status = PremiumStatus(
      isPremium: false,
      priceDisplay: _status.priceDisplay,
      isTurkishUser: _status.isTurkishUser,
    );
    notifyListeners();
  }
}
