/// speech_to_text hatalarını sınıflandırır.
///
/// iOS eklentisi tüm tanıma hatalarını `permanent: true` olarak bildirdiği için
/// bu bayrağa güvenilemez. "Konuşma algılanmadı" gibi geçici hatalarda dinleme
/// yeniden başlatılabilir; tanıma motoru hiç başlatılamıyorsa (ör. iOS 26.4
/// simülatöründeki `error_unknown (300)`) yeniden denemek sonsuz döngü yaratır.
class SpeechErrorHelper {
  static const Set<String> _retryable = {
    'error_no_match',
    'error_speech_timeout',
    'error_retry',
    'error_request_cancelled',
    'error_speech_recognizer_connection_interrupted',
    'error_busy',
  };

  /// Yeniden denemenin anlamsız olduğu hata mı
  static bool isFatal(String errorMsg) => !_retryable.contains(errorMsg);

  static const String unavailableMessage =
      "Speech recognition isn't available on this device right now. "
      'On the iOS Simulator this is a known Apple issue, so please test on a real iPhone. '
      'You can type your answer instead.';
}
