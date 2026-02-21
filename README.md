# 🎓 Elo English - AI-Powered English Learning App

An interactive English language learning application built with **Flutter** and powered by **Google Gemini AI**. Practice real-life conversations, prepare for IELTS Speaking exams, and track your progress — all with AI-driven feedback.

---

## ✨ Features

### 🗣️ Conversation Practice
- **Real-life scenarios** — Practice ordering at restaurants, shopping, airport check-in, meeting new people, and more
- **AI-powered conversations** — Natural dialogue powered by Google Gemini
- **Instant feedback** — Grammar corrections, vocabulary suggestions, and personalized tips after each message
- **Speech-to-Text** — Use your microphone to speak and get your words transcribed automatically
- **Text-to-Speech** — Listen to AI responses with natural pronunciation

### 📝 IELTS Speaking Exam
- **Full 3-part IELTS simulation** — Part 1 (Introduction), Part 2 (Cue Card), Part 3 (Discussion)
- **Band score evaluation** — Get detailed scoring across Fluency, Vocabulary, Grammar, and Pronunciation
- **Timed practice** — Realistic exam timing with countdown

### 📊 Progress Tracking
- Total conversations completed
- Time spent practicing
- Completed scenarios
- Level progression (Beginner → Intermediate → Advanced)
- Weekly XP tracking

### 🏆 Leaderboard
- Weekly ranking system
- XP-based competition with other learners
- Profile avatars

### 👤 User Account
- Firebase Authentication (Email/Password)
- Profile customization with avatar upload
- Premium membership system

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) |
| **Backend** | FastAPI (Python) |
| **AI Engine** | Google Gemini API |
| **Authentication** | Firebase Auth |
| **Speech Recognition** | speech_to_text (on-device) |
| **Text-to-Speech** | flutter_tts |
| **State Management** | Provider |
| **Local Storage** | SharedPreferences |

---

## 📁 Project Structure

```
elo/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── models/
│   │   └── models.dart           # Data models (Scenario, Message, UserProgress, etc.)
│   ├── providers/
│   │   ├── auth_provider.dart    # Authentication state
│   │   ├── conversation_provider.dart  # Conversation management
│   │   ├── ielts_provider.dart   # IELTS exam state
│   │   ├── premium_provider.dart # Premium membership
│   │   └── user_provider.dart    # User progress & stats
│   ├── screens/
│   │   ├── home_screen.dart      # Home dashboard
│   │   ├── scenario_list_screen.dart  # Browse conversation scenarios
│   │   ├── conversation_screen.dart   # Active conversation
│   │   ├── ielts_exam_screen.dart     # IELTS Speaking exam
│   │   ├── progress_screen.dart       # Learning statistics
│   │   ├── leaderboard_screen.dart    # Weekly rankings
│   │   ├── account_screen.dart        # User profile
│   │   ├── login_screen.dart          # Authentication
│   │   ├── register_screen.dart       # Registration
│   │   └── notifications_screen.dart  # Notifications
│   ├── services/
│   │   ├── api_service.dart      # Backend API client
│   │   ├── auth_service.dart     # Firebase auth service
│   │   └── notification_service.dart  # Local notifications
│   ├── widgets/
│   │   └── premium_popup.dart    # Premium membership dialog
│   └── backend/
│       └── main.py               # FastAPI backend server
├── android/                      # Android platform files
├── ios/                          # iOS platform files
└── pubspec.yaml                  # Flutter dependencies
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (≥ 3.7.2)
- Python 3.12+
- Google Gemini API Key
- Firebase Project (for authentication)

### 1. Clone the repository

```bash
git clone https://github.com/birolshn/Elo-English.git
cd Elo-English
```

### 2. Set up the Backend

```bash
cd lib/backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create a `.env` file in `lib/backend/`:

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

Start the backend server:

```bash
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000` with Swagger docs at `http://localhost:8000/docs`.

### 3. Set up the Flutter App

```bash
cd ../..  # Back to project root
flutter pub get
flutter run
```

> **Note:** The app auto-detects the platform and uses `10.0.2.2:8000` for Android Emulator and `localhost:8000` for iOS Simulator.

---

## 📱 Available Scenarios

| Scenario | Difficulty | Description |
|----------|-----------|-------------|
| 🍽️ Restaurant | Beginner | Practice ordering food |
| 🛍️ Shopping | Beginner | Learn shopping vocabulary |
| ✈️ Airport | Intermediate | Check-in & security procedures |
| 👋 Meeting People | Beginner | Casual conversation practice |

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|---------|-------------|
| `GET` | `/scenarios` | List all scenarios |
| `POST` | `/conversation` | Send message & get AI response |
| `GET` | `/user/progress/{id}` | Get user progress |
| `POST` | `/user/progress/{id}` | Update user progress |
| `GET` | `/leaderboard` | Weekly leaderboard |
| `POST` | `/ielts/conversation` | IELTS speaking conversation |
| `POST` | `/ielts/evaluate` | Get IELTS band score |
| `POST` | `/upload/avatar` | Upload profile picture |

---

## 🛡️ Environment Variables

| Variable | Description |
|----------|------------|
| `GEMINI_API_KEY` | Google Gemini API key for AI conversations |

---

## 📄 License

This project is for educational purposes.

---

## 👨‍💻 Author

**Birol Şahin** — [@birolshn](https://github.com/birolshn)
