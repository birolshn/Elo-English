import 'dart:io';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/notification_service.dart';

class PremiumProvider with ChangeNotifier {
  bool _isPremium = false;
  bool _isLoading = false;
  String? _subscriptionType;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get subscriptionType => _subscriptionType;

  PremiumProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await checkPremiumStatus();

    _isLoading = false;
    notifyListeners();
  }

  /// RevenueCat'ten premium durumunu kontrol et
  Future<void> checkPremiumStatus() async {
    try {
      if (!Platform.isIOS) return;

      final customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('RevenueCat premium kontrol hatası: $e');
      _isPremium = false;
    }
    notifyListeners();
  }

  void _updatePremiumFromCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all['premium'];
    _isPremium = entitlement?.isActive ?? false;

    if (_isPremium) {
      final productId = entitlement?.productIdentifier ?? '';
      if (productId.contains('yearly') || productId.contains('annual')) {
        _subscriptionType = 'yearly';
      } else if (productId.contains('6month')) {
        _subscriptionType = '6month';
      } else if (productId.contains('3month')) {
        _subscriptionType = '3month';
      } else {
        _subscriptionType = 'monthly';
      }
    } else {
      _subscriptionType = null;
    }

    // Update notifications based on new premium status
    NotificationService().setupNotifications(isPremium: _isPremium);
  }

  /// RevenueCat paywall'ını göster
  Future<bool> showPaywall() async {
    try {
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded('premium');

      if (paywallResult == PaywallResult.purchased ||
          paywallResult == PaywallResult.restored) {
        await checkPremiumStatus();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Paywall hatası: $e');
      return false;
    }
  }

  /// Satın alma işlemini geri yükle
  Future<bool> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumFromCustomerInfo(customerInfo);

      _isLoading = false;
      notifyListeners();
      return _isPremium;
    } catch (e) {
      debugPrint('Restore hatası: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- UI İçin Fiyat Getters (Gerekirse) ---

  bool get _isTR => _detectTurkishUser();

  String get monthlyPrice => _isTR ? '129 TL' : '\$5.99';
  String get threeMonthPrice => _isTR ? '299 TL' : '\$14.99';
  String get sixMonthPrice => _isTR ? '499 TL' : '\$24.99';
  String get yearlyPrice => _isTR ? '799 TL' : '\$39.99';

  // Yıllık paketin aylık karşılığı (reklam için)
  String get yearlyMonthlyEquivalent => _isTR ? '66 TL' : '\$3.33';

  bool _detectTurkishUser() {
    try {
      final locale = Platform.localeName;
      return locale.toLowerCase().contains('tr');
    } catch (e) {
      return false;
    }
  }
}
