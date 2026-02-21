import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/main_tab_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/scenario_list_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/ielts_exam_screen.dart';
import 'screens/notifications_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/user_provider.dart';
import 'providers/premium_provider.dart';
import 'providers/ielts_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Bildirimleri başlat
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

class AppTheme {
  // Brand colors for AI English Learning App
  static const Color primaryBlue = Color(0xFF2563EB); // Deep Professional Blue
  static const Color primaryTeal = Color(0xFF0891B2); // Modern Teal
  static const Color accentGreen = Color(0xFF10B981); // Success Green
  static const Color accentOrange = Color(0xFFF97316); // Warm Orange
  static const Color accentPurple = Color(0xFF9333EA); // Learning Purple
  static const Color accentPink = Color(0xFFEC4899); // Engagement Pink

  static const Color lightBg = Color(0xFFF8FAFC); // Light Background
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF1E293B); // Dark Text
  static const Color lightText = Color(0xFF64748B); // Light Gray Text

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryTeal,
        tertiary: accentPurple,
        surface: white,
        background: lightBg,
        error: const Color(0xFFDC2626),
        onPrimary: white,
        onSecondary: white,
        onSurface: darkText,
      ),
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: darkText,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkText,
          letterSpacing: -0.3,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightText,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        color: white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: lightBg,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update:
              (_, auth, userProvider) =>
                  userProvider!..updateAuthUser(auth.user),
        ),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
        ChangeNotifierProvider(create: (_) => IeltsProvider()),
      ],
      child: MaterialApp(
        title: 'AI English Partner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/scenarios': (context) => const ScenarioListScreen(),
          '/conversation': (context) => const ConversationScreen(),
          '/progress': (context) => const ProgressScreen(),
          '/ielts-exam': (context) => const IeltsExamScreen(),
          '/notifications': (context) => const NotificationsScreen(),
        },
      ),
    );
  }
}

/// Wrapper widget that handles authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _notificationsSetup = false;

  void _setupNotifications(bool isPremium) async {
    if (_notificationsSetup) return;
    _notificationsSetup = true;

    final notificationService = NotificationService();
    await notificationService.setupNotifications(isPremium: isPremium);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show loading while checking auth state
    if (authProvider.status == AuthStatus.initial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Redirect based on auth state
    if (authProvider.isAuthenticated) {
      // Bildirimleri kur (premium durumuna göre)
      final premiumProvider = context.read<PremiumProvider>();
      _setupNotifications(premiumProvider.isPremium);
      return const MainTabScreen();
    } else {
      return const LoginScreen();
    }
  }
}
