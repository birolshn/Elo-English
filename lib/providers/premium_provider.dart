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

  // Dynamic Prices
  String _monthlyPrice = '';
  String _threeMonthPrice = '';
  String _sixMonthPrice = '';
  String _yearlyPrice = '';
  String _yearlyMonthlyEquivalent = '';

  // Yıllık plandaki ücretsiz deneme (App Store / Play Console'da tanımlı intro offer)
  int? _yearlyTrialDays;
  bool _trialEligible = true;

  /// Kullanıcı uygunsa yıllık planın ücretsiz deneme süresi (gün); yoksa null.
  /// Mağazada deneme tanımlı değilse null döner, arayüz deneme vaat etmez.
  int? get yearlyTrialDays => _trialEligible ? _yearlyTrialDays : null;
  bool get hasYearlyTrial => yearlyTrialDays != null;

  /// Ürün bilgisinden ücretsiz deneme süresini hesapla (iOS intro price / Android free phase)
  static int? freeTrialDaysFrom({IntroductoryPrice? intro, SubscriptionOption? option}) {
    int toDays(PeriodUnit unit, int value) {
      switch (unit) {
        case PeriodUnit.day:
          return value;
        case PeriodUnit.week:
          return value * 7;
        case PeriodUnit.month:
          return value * 30;
        case PeriodUnit.year:
          return value * 365;
        case PeriodUnit.unknown:
          return 0;
      }
    }

    if (intro != null && intro.price == 0) {
      final days = toDays(intro.periodUnit, intro.periodNumberOfUnits) * (intro.cycles > 0 ? intro.cycles : 1);
      if (days > 0) return days;
    }
    final freePeriod = option?.freePhase?.billingPeriod;
    if (freePeriod != null) {
      final days = toDays(freePeriod.unit, freePeriod.value);
      if (days > 0) return days;
    }
    return null;
  }

  PremiumProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await checkPremiumStatus();
    await _fetchOfferings();

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

  /// RevenueCat'ten mevcut fiyatları çek
  Future<void> _fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current != null) {
        _monthlyPrice = current.monthly?.storeProduct.priceString ?? '';
        _threeMonthPrice = current.threeMonth?.storeProduct.priceString ?? '';
        _sixMonthPrice = current.sixMonth?.storeProduct.priceString ?? '';
        _yearlyPrice = current.annual?.storeProduct.priceString ?? '';

        // debugPrint('Dynamic Prices Fetched:');
        // debugPrint('Monthly: $_monthlyPrice');
        // debugPrint('Yearly: $_yearlyPrice');

        // Yıllık plandaki ücretsiz deneme ve kullanıcının uygunluğu
        final annualProduct = current.annual?.storeProduct;
        _yearlyTrialDays = annualProduct == null
            ? null
            : freeTrialDaysFrom(
                intro: annualProduct.introductoryPrice,
                option: annualProduct.defaultOption,
              );
        if (_yearlyTrialDays != null && annualProduct != null && Platform.isIOS) {
          try {
            final eligibility = await Purchases.checkTrialOrIntroductoryPriceEligibility(
              [annualProduct.identifier],
            );
            final status = eligibility[annualProduct.identifier]?.status;
            // Daha önce deneme kullananlara yeniden "ücretsiz" denmesin
            _trialEligible = status != IntroEligibilityStatus.introEligibilityStatusIneligible;
          } catch (e) {
            debugPrint('Trial eligibility error: $e');
          }
        }

        // Yıllık paketin aylık karşılığını hesapla
        if (current.annual != null) {
          final annualProduct = current.annual!.storeProduct;
          final monthlyEquivalent = annualProduct.price / 12;

          // Basit formatlama (Para birimi simgesi + rakam)
          final symbol = _extractCurrencySymbol(annualProduct.priceString);
          _yearlyMonthlyEquivalent =
              symbol + monthlyEquivalent.toStringAsFixed(2);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fiyat çekme hatası: $e');
    }
  }

  String _extractCurrencySymbol(String priceString) {
    // Fiyat metninden rakam olmayan baş/son karakterleri al
    return priceString.replaceAll(RegExp(r'[0-9.,\s]'), '');
  }

  void _updatePremiumFromCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all['premium'];
    _isPremium = entitlement?.isActive ?? false;

    // Deneme sürüyorsa bitmeden 2 gün önce hatırlat (deneme ekranında verilen söz)
    if (_isPremium && entitlement?.periodType == PeriodType.trial) {
      final expiration = DateTime.tryParse(entitlement?.expirationDate ?? '');
      if (expiration != null) {
        NotificationService().scheduleTrialEndingReminder(expiration.toLocal());
      }
    }

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
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
        'premium',
      );

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

  /// Seçilen planı doğrudan satın al (paywall göstermeden)
  Future<bool> purchaseSelectedPlan(String planId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // RevenueCat'ten mevcut ürünleri al
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering == null) {
        debugPrint('❌ No current offering found');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // planId'ye göre doğru paketi bul
      Package? targetPackage;

      // Önce package type ile eşleştir
      switch (planId) {
        case 'monthly':
          targetPackage = currentOffering.monthly;
          break;
        case '3month':
          targetPackage = currentOffering.threeMonth;
          break;
        case '6month':
          targetPackage = currentOffering.sixMonth;
          break;
        case 'yearly':
          targetPackage = currentOffering.annual;
          break;
      }

      // Package type ile bulunamadıysa, identifier ile ara
      if (targetPackage == null) {
        for (final pkg in currentOffering.availablePackages) {
          if (pkg.identifier.contains(planId)) {
            targetPackage = pkg;
            break;
          }
        }
      }

      if (targetPackage == null) {
        debugPrint('❌ Package not found for plan: $planId');
        debugPrint(
          'Available packages: ${currentOffering.availablePackages.map((p) => p.identifier).toList()}',
        );
        _isLoading = false;
        notifyListeners();
        // Fallback: paywall göster
        return showPaywall();
      }

      debugPrint('✅ Purchasing package: ${targetPackage.identifier}');
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(targetPackage),
      );
      _updatePremiumFromCustomerInfo(purchaseResult.customerInfo);

      _isLoading = false;
      notifyListeners();
      return _isPremium;
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      _isLoading = false;
      notifyListeners();
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

  String get monthlyPrice =>
      _monthlyPrice.isNotEmpty ? _monthlyPrice : (_isTR ? '149 TL' : '\$6.99');
  String get threeMonthPrice =>
      _threeMonthPrice.isNotEmpty
          ? _threeMonthPrice
          : (_isTR ? '389 TL' : '\$17.99');
  String get sixMonthPrice =>
      _sixMonthPrice.isNotEmpty
          ? _sixMonthPrice
          : (_isTR ? '699 TL' : '\$32.99');
  String get yearlyPrice =>
      _yearlyPrice.isNotEmpty ? _yearlyPrice : (_isTR ? '1199 TL' : '\$54.99');

  // Yıllık paketin aylık karşılığı (reklam için)
  String get yearlyMonthlyEquivalent =>
      _yearlyMonthlyEquivalent.isNotEmpty
          ? _yearlyMonthlyEquivalent
          : (_isTR ? '99 TL' : '\$4.58');

  bool _detectTurkishUser() {
    try {
      final locale = Platform.localeName;
      debugPrint('Detecting locale: $locale');
      return locale.toLowerCase().contains('tr') ||
          locale.toLowerCase().contains('tur');
    } catch (e) {
      return false;
    }
  }
}
