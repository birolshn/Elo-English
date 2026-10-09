# 🚀 Elo English - Proje Analizi ve Özellik Önerileri Yol Haritası

Bu belge, **Elo English** uygulamasının mevcut mimarisini, güçlü ve zayıf yönlerini, kullanıcı deneyimini (UX), pedagojik değerini ve gelir modelini (monetization) katbekat artıracak yeni özellik önerilerini detaylı ve anlaşılır bir şekilde sunar.

---

## 📌 İçindekiler
1. [Mevcut Proje Mimarisi ve Durum Özeti](#1-mevcut-proje-mimarisi-ve-durum-özeti)
2. [En Kritik & Yüksek Etkili Özellikler (AI & Konuşma Deneyimi)](#2-en-kritik--yüksek-etkili-özellikler-ai--konuşma-deneyimi)
3. [Öğrenme ve Kalıcılık Özellikleri (Retention & Pedagoji)](#3-öğrenme-ve-kalıcılık-özellikleri-retention--pedagoji)
4. [IELTS ve Akademik Sınav Modülü Geliştirmeleri](#4-ielts-ve-akademik-sınav-modülü-geliştirmeleri)
5. [Oyunlaştırma (Gamification) & Sosyal Özellikler](#5-oyunlaştırma-gamification--sosyal-özellikler)
6. [UI/UX, Tasarım ve Kişiselleştirme](#6-uiux-tasarım-ve-kişiselleştirme)
7. [Teknik Altyapı, Güvenlik ve Performans](#7-teknik-altyapı-güvenlik-ve-performans)
8. [Uygulama Yol Haritası (Önceliklendirilmiş Fazlar)](#8-uygulama-yol-haritası-önceliklendirilmiş-fazlar)

---

## 1. Mevcut Proje Mimarisi ve Durum Özeti

### 📱 Mobil Uygulama (Flutter)
- **Durum Yönetimi:** `Provider` mimarisi (`UserProvider`, `ConversationProvider`, `IeltsProvider`, `ScenarioProvider`, `PremiumProvider`, `AuthProvider`).
- **Veritabanı & Kimlik:** `Firebase Auth` (E-posta/Şifre), `Cloud Firestore` (Kullanıcı profilleri, haftalık XP, kullanım süreleri, tamamlanan senaryolar).
- **Abonelik & Gelir:** `RevenueCat` (`purchases_flutter`), iOS StoreKit entegrasyonu, ücretsiz kullanıcılara günlük 2 senaryo hakkı.
- **Ses & Konuşma:** `speech_to_text` (Cihazın yerel STT motoru), `flutter_tts` (Cihaz yerel sesi), Google Cloud TTS (`Neural2` sesleri).
- **Bildirimler:** `flutter_local_notifications` ve `timezone` ile günlük hatırlatıcılar ve motivasyon mesajları.

### 🖥️ Backend (FastAPI / Python)
- **Sunucu:** Render.com üzerinde çalışan durumsuz (stateless) FastAPI servisi.
- **Yapay Zeka:** Google Gemini (`gemini-2.5-flash`) ile rol yapma (roleplay), sohbet yönlendirme, gramer düzeltmeleri ve IELTS Band Skoru değerlendirmesi.

---

## 2. En Kritik & Yüksek Etkili Özellikler (AI & Konuşma Deneyimi)

### 2.1. 📞 Gerçek Zamanlı "Telefon Araması" Modu (Hands-Free Call Mode)
- **Sorun:** Kullanıcılar şu an her konuşmadan önce mikrofona basmak, konuşmayı bitirince beklemek veya metin moduna geçmek zorunda. Bu durum gerçek bir konuşma akıcılığı hissini kırıyor.
- **Çözüm:** Tıpkı WhatsApp veya FaceTime araması gibi tam ekran bir arama arayüzü ekleyin.
  - **VAD (Voice Activity Detection - Ses Aktivite Algılama):** Kullanıcı konuşmayı bıraktığı an sistem otomatik algılar ve AI cevap verir.
  - Arayüzde konuşan yapay zeka avatarı veya hafif dalgalanan modern bir ses dalgası animasyonu (waveform) yer alır.
  - Kullanıcı yürüyüş yaparken, arabada veya kulaklıkla telefonu cebinden çıkarmadan pratik yapabilir.

### 2.2. 🎯 Telaffuz ve Vurgu Analizi (Pronunciation & Accent Scoring)
- **Sorun:** Mevcut sistem kullanıcının söylediklerini metne dönüştürüyor; fakat kullanıcının kelimeleri doğru telaffuz edip etmediğini, vurguları (stress) ve tonlamayı değerlendiremiyor.
- **Çözüm:**
  - Konuşulan her cümlenin ardından kelime bazlı renkli skorlama (Yeşil: Kusursuz, Sarı: Anlaşılır ama aksanlı, Kırmızı: Hatalı telaffuz).
  - Tıklanan hatalı kelimenin fonetik okunuşu (IPA - International Phonetic Alphabet) ve doğru sesletim örneği ("Listen & Repeat").
  - Özellikle Türk kullanıcıların en çok zorlandığı seslere özel pratikler: `/θ/` (th), `/w/` vs `/v/`, `/r/` sesleri.

### 2.3. ⚡ Canlı Akış (Streaming Responses - Düşük Gecikme)
- **Sorun:** Gemini tüm cevabı oluşturana kadar kullanıcı 2-4 saniye bekliyor.
- **Çözüm:** Server-Sent Events (SSE) veya WebSocket ile cevabın kelime kelime ekrana akması (streaming). AI ilk cümleyi üretir üretmez ses motoru (TTS) konuşmaya başlar. Böylece bekleme süresi 0.5 saniyeye iner.

### 2.4. 🎭 "Kendi Senaryonu Yarat" (Custom Scenario Creator)
- **Sorun:** Mevcut 5-6 senaryo (Restoran, Mülakat, Alışveriş, Havalimanı, Sohbet) bir süre sonra tüketilir ve monotonlaşır.
- **Çözüm:** Kullanıcının istediği herhangi bir durumu yazıp anında senaryo oluşturabilmesi:
  - *Örnek:* "Ev sahibimle kira zammını müzakere etmek istiyorum."
  - *Örnek:* "Yurt dışında doktora gidip sırt ağrımı tarif etmek istiyorum."
  - *Örnek:* "Yazılım şirketinde backend mimarisi üzerine teknik mülakat."
  - AI anında uygun ortamı, rolleri ve hedefleri belirleyip simülasyonu başlatır.

---

## 3. Öğrenme ve Kalıcılık Özellikleri (Retention & Pedagoji)

### 3.1. 📒 Hata Defteri & Hata Düzeltme Pratiği (Mistake Vault)
- **Sorun:** Konuşma sırasında Gemini'nin verdiği gramer düzeltmeleri ve öneriler konuşma penceresinde kaybolup gidiyor. Kullanıcı hatalarından ders çıkaramıyor.
- **Çözüm:**
  - Kullanıcının konuşmalarda yaptığı tüm hataların otomatik olarak "Hatalarım" sayfasına kaydedilmesi.
  - Hatanın açıklaması: *"You said: 'I have went there' ➔ Better: 'I went there' (Rule: Past Simple vs Present Perfect)"*.
  - **"Hataları Temizle" Testi:** Kullanıcının geçmiş hatalarından türetilen 3 dakikalık mini boşluk doldurma veya düzeltme alıştırması.

### 3.2. 🧠 Kelime Bankası ve Aralıklı Tekrar (SRS / Flashcards)
- **Sorun:** AI'ın önerdiği zengin kelimeler (vocabulary suggestions) bir defa görünüp unutuluyor.
- **Çözüm:**
  - Sohbet esnasında AI'ın önerdiği kelimelerin yanında küçük bir **"Yıldızla / Kaydet" (Bookmark)** ikonu.
  - Ana menüde "Kelime Defterim" sekmesi.
  - **SuperMemo / Anki benzeri Spaced Repetition (Aralıklı Tekrar):** Kaydedilen kelimeler 1 gün, 3 gün, 7 gün sonra mini bildirimlerle veya flaş kartlarla kullanıcıya hatırlatılır.

### 3.3. 🗣️ Gölgeleme Tekniği Modu (Shadowing / Listen & Repeat)
- **Fayda:** Dil öğreniminde akıcılığı ve doğru ağız kası hafızasını geliştiren en kanıtlanmış yöntemdir.
- **İşleyiş:** AI doğal bir aksanla bir cümle söyler; kullanıcı bu cümleyi aynı hız ve tonlamayla tekrar eder. Sistem telaffuz benzerliğini yüzde (%) olarak puanlar.

### 3.4. 📼 Sohbet Geçmişi ve Ses Kaydı Arşivi
- **Fayda:** Kullanıcıların 1 ay önceki konuşmaları ile bugünkü konuşmalarını kıyaslayarak somut ilerlemelerini görmesi motivasyonu inanılmaz artırır.
- Kullanıcı geçmiş konuşmalarını okuyabilmeli, aldığı geri bildirimleri inceleyebilmeli ve kendi konuşma süresinin gelişim grafiğini görebilmelidir.

---

## 4. IELTS ve Akademik Sınav Modülü Geliştirmeleri

### 4.1. 📋 Gerçek Sınav Konu Kartları Havuzu (2025-2026 Cambridge/IDP)
- Part 2 için rastgele veya seçilebilir gerçek sınav konuları (Cue Cards).
- Part 1 için ısınma konuları kategorileri: İş, Eğitim, Sanat, Teknoloji, Aile, Seyahat.
- Part 3 için soyut ve felsefi tartışma soruları.

### 4.2. 📄 İndirilebilir IELTS Karnesi & Detaylı Band Skoru Raporu (PDF)
- Sınav bitiminde 4 resmi IELTS kriterine göre detaylı skor kartı:
  1. **Fluency and Coherence (Akıcılık ve Tutarlılık)**
  2. **Lexical Resource (Kelime Çeşitliliği ve Zenginliği)**
  3. **Grammatical Range and Accuracy (Gramer Çeşitliliği ve Doğruluğu)**
  4. **Pronunciation (Telaffuz ve Anlaşılırlık)**
- *"Skorunuzu 6.0'dan 7.5'e çıkarmak için şunlara dikkat edin"* şeklinde somut yapay zeka tavsiyeleri.
- Tek dokunuşla WhatsApp veya e-posta ile paylaşılabilecek şık bir PDF sınav raporu.

### 4.3. 🎓 Diğer Sınav Formatları (TOEFL, PTE, YDS/YÖKDİL Konuşma)
- Sadece IELTS ile sınırlı kalmayıp, **TOEFL iBT Speaking** ve **Duolingo English Test (DET)** formatları için hazır şablonlar eklenmesi.

---

## 5. Oyunlaştırma (Gamification) & Sosyal Özellikler

### 5.1. 🛡️ Seri Dondurucu (Streak Freeze) ve Seri Kurtarma
- **Kritik Retention Unsuru:** Kullanıcılar 15 günlük serilerini 1 gün yoğunluktan kaçırdıklarında uygulamayı tamamen bırakma eğilimi gösterirler (Duolingo sendromu).
- Haftada 1 kez kullanılabilen "Seri Dondurucu" (Streak Freeze) veya XP harcayarak seriyi kurtarma özelliği eklenmelidir.

### 5.2. ⚔️ Arkadaşla Konuşma Düellosu (Speaking Duel)
- İki kullanıcıya aynı konu verilir (Örn: *"Remote work vs Office work"*).
- Her kullanıcı 1'er dakikalık ses kaydı ile argümanını sunar.
- AI her iki kullanıcının kelime zenginliğini, gramerini ve argüman gücünü puanlayarak kazananı belirler.

### 5.3. 🎯 Günlük Görevler & Haftalık Rozetler (Quests)
- *"Bugün 3 farklı sıfat kullan."*
- *"Havalimanı senaryosunu tamamla."*
- *"En az 5 dakika kesintisiz konuş."*
- Görevler tamamlandığında ekstra XP, seviye atlama animasyonları ve profil unvanları ("Fluent Explorer", "Grammar Master" vb.).

---

## 6. UI/UX, Tasarım ve Kişiselleştirme

### 6.1. 🌙 Tam Karanlık Mod (Dark Mode)
- Uygulama şu anda yalnızca açık temaya (`lightTheme`) sahip. Gece pratik yapan kullanıcılar için modern, göz yormayan OLED dostu bir koyu tema eklenmelidir.

### 6.2. 🌍 Çift Dil Desteği (Tam Türkçe / İngilizce Arayüz)
- Yeni başlayan (A1-A2) seviyesindeki kullanıcılar için tamamen İngilizce arayüz bazen caydırıcı olabilir.
- Ayarlar kısmından tek tuşla arayüz dilini (Türkçe / İngilizce) değiştirebilme ve sohbet içi anlık çeviri butonu ("Translate to Turkish").

### 6.3. 🎭 AI Karakter & Aksan Seçimi
- Konuşulan yapay zekanın karakterini ve aksanını seçebilme:
  - 🇺🇸 **Emma (New York):** Hızlı, enerjik, samimi Amerikan aksanı.
  - 🇬🇧 **Oliver (London):** Kibar, resmi, zengin kelime dağarcığına sahip İngiliz aksanı.
  - 🇦🇺 **Liam (Sydney):** Rahat, günlük konuşma Avustralya aksanı.

---

## 7. Teknik Altyapı, Güvenlik ve Performans

### 7.1. 🔒 Backend Güvenliği (Firebase JWT Token Doğrulaması)
- **Mevcut Açık:** Render üzerindeki FastAPI servisinin endpoint'leri (`/conversation`, `/ielts/conversation` vb.) herkese açık. Mobil uygulamanın kullandığı URL'i bilen herhangi biri API anahtarı olmadan bu servisi çağırıp Gemini kotanızı tüketebilir.
- **Çözüm:** FastAPI'ye bir Dependency/Middleware eklenerek gelen isteklerin `Authorization: Bearer <Firebase_ID_Token>` başlığıyla doğrulanması ve sadece giriş yapmış kullanıcılara cevap verilmesi.

### 7.2. 🎙️ Profesyonel STT Entegrasyonu (Cloud Whisper / Deepgram)
- **Sorun:** Cihazların yerel `speech_to_text` motoru bazen kullanıcının Türk aksanlı İngilizcesini yanlış anlayabilir veya gürültülü ortamlarda kesilebilir. Backend'deki AssemblyAI kodu ise pasife alınmış durumda.
- **Çözüm:** OpenAI Whisper API, Groq Whisper (ultra hızlı ~200ms) veya Deepgram API ile backend üzerinden doğrudan yüksek doğruluklu ses tanıma altyapısı.

### 7.3. 📴 Çevrimdışı (Offline) Mod
- İnternet bağlantısı koptuğunda kullanıcının en azından kaydedilmiş kelimelerini, gramer notlarını ve indirilmiş ses kartlarını çalışabilmesi.

---

## 8. Uygulama Yol Haritası (Önceliklendirilmiş Fazlar)

| Faz | Odak Alanı | Özellikler | Beklenen Etki |
|---|---|---|---|
| **Faz 1: Hızlı Kazanımlar (1-2 Hafta)** | Retention & UX | • Hata Defteri (Mistake Vault)<br>• Kelime Kaydetme & Flaş Kartlar<br>• Streak Freeze (Seri Dondurucu)<br>• Sohbet içi Türkçeye Çevir butonu | Günlük aktif kullanıcı (DAU) ve geri dönüş oranında %40 artış |
| **Faz 2: AI & Ses Devrimi (2-4 Hafta)** | Konuşma Deneyimi | • Hands-Free Telefon Görüşmesi Modu<br>• Streaming (Canlı yanıt akışı)<br>• Kendi Senaryonu Yarat Modu<br>• Backend API Token Doğrulaması | Uygulama kullanım süresinde ve mağaza puanlarında sıçrama |
| **Faz 3: Sınav & Değerlendirme (4-6 Hafta)** | Monetization & Premium | • Telaffuz / Fonetik Hata Analizi<br>• Detaylı PDF IELTS Karnesi<br>• Aksan Seçimi (Amerikan / İngiliz)<br>• Dark Mode desteği | Premium abonelik dönüşüm oranında (Conversion Rate) ciddi artış |
| **Faz 4: Sosyal & Topluluk (Gelecek)** | Viral Büyüme | • Arkadaş Ekleme & Konuşma Düelloları<br>• Haftalık Ligler & Kulüpler | Organik kullanıcı kazanımı ve sosyal paylaşım |

---

> 💡 **Sonuç Notu:** Elo English, halihazırda temiz bir mimariye, sağlam bir temel UI tasarımına ve çalışan bir yapay zeka entegrasyonuna sahip. Yukarıdaki yol haritası adım adım uygulandığında, uygulama sıradan bir "chatbot" olmaktan çıkıp, kullanıcıların hayatına dokunan gerçek bir **Kişisel AI İngilizce Eğitmeni** haline gelecektir.
