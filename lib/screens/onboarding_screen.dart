import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data model for a goal option
class GoalOption {
  final String label;
  final IconData icon;
  final String emoji;

  const GoalOption({
    required this.label,
    required this.icon,
    required this.emoji,
  });
}

/// Data model for a level option
class LevelOption {
  final String label;
  final String description;
  final String emoji;
  final Color color;

  const LevelOption({
    required this.label,
    required this.description,
    required this.emoji,
    required this.color,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedGoal;
  String? _selectedLevel;
  int? _selectedDailyGoal;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Goal options
  static const List<GoalOption> _goalOptions = [
    GoalOption(label: 'Travel', icon: Icons.flight_takeoff_rounded, emoji: '✈️'),
    GoalOption(label: 'Job Interview', icon: Icons.work_rounded, emoji: '💼'),
    GoalOption(label: 'IELTS', icon: Icons.school_rounded, emoji: '🎓'),
    GoalOption(label: 'Daily Speaking', icon: Icons.chat_bubble_rounded, emoji: '💬'),
  ];

  // Level options
  static const List<LevelOption> _levelOptions = [
    LevelOption(
      label: 'Beginner',
      description: 'I know basic words and phrases',
      emoji: '🌱',
      color: Color(0xFF10B981),
    ),
    LevelOption(
      label: 'Intermediate',
      description: 'I can hold simple conversations',
      emoji: '🌿',
      color: Color(0xFF3B82F6),
    ),
    LevelOption(
      label: 'Advanced',
      description: 'I want to sound more natural',
      emoji: '🌳',
      color: Color(0xFF9333EA),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (_selectedGoal != null) {
      await prefs.setString('user_goal', _selectedGoal!);
    }
    if (_selectedLevel != null) {
      await prefs.setString('user_level', _selectedLevel!);
    }
    if (_selectedDailyGoal != null) {
      await prefs.setInt('daily_goal_minutes', _selectedDailyGoal!);
    }

    if (mounted) {
      widget.onComplete?.call();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Re-trigger animations
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Animated gradient background
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(),
                ),
              ),
            ),

            // Decorative circles
            _buildDecorativeCircles(),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Top bar with back button and page indicator
                  _buildTopBar(),

                  // Page view
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildHookPage(),
                        _buildGoalPage(),
                        _buildLevelPage(),
                        _buildDailyGoalPage(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (_currentPage) {
      case 0:
        return [
          const Color(0xFF1E3A8A),
          const Color(0xFF2563EB),
          const Color(0xFF0891B2),
        ];
      case 1:
        return [
          const Color(0xFF1E293B),
          const Color(0xFF334155),
          const Color(0xFF1E3A8A),
        ];
      case 2:
        return [
          const Color(0xFF1E1B4B),
          const Color(0xFF4338CA),
          const Color(0xFF7C3AED),
        ];
      case 3:
        return [
          const Color(0xFF064E3B),
          const Color(0xFF047857),
          const Color(0xFF10B981),
        ];
      default:
        return [
          const Color(0xFF1E3A8A),
          const Color(0xFF2563EB),
          const Color(0xFF0891B2),
        ];
    }
  }

  Widget _buildDecorativeCircles() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -50,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Back button (hidden on first page)
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _currentPage > 0 ? _goToPreviousPage : null,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Page indicator dots
          Row(
            children: List.generate(4, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 28 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const Spacer(),

          // Skip button (hidden on last page)
          AnimatedOpacity(
            opacity: _currentPage < 3 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: _currentPage < 3 ? () => _completeOnboarding() : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SCREEN 1: Hook ─────────────────────────────────────────────────

  Widget _buildHookPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mic_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Title
              const Text(
                'Speak English\nwith AI in\n2 minutes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'No partner needed. Just start talking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 3),

              // CTA Button
              _buildPrimaryButton(
                label: 'Start Speaking',
                onTap: _goToNextPage,
                icon: Icons.arrow_forward_rounded,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SCREEN 2: Goal Selection ────────────────────────────────────────

  Widget _buildGoalPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // Title
              const Text(
                'Why are you\nlearning English?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'This helps us personalize your experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),

              const SizedBox(height: 36),

              // Goal options
              ...List.generate(_goalOptions.length, (index) {
                final option = _goalOptions[index];
                final isSelected = _selectedGoal == option.label;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOptionCard(
                    label: option.label,
                    emoji: option.emoji,
                    icon: option.icon,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedGoal = option.label);
                    },
                  ),
                );
              }),

              const Spacer(flex: 2),

              // Continue button
              _buildPrimaryButton(
                label: 'Continue',
                onTap: _selectedGoal != null ? _goToNextPage : null,
                icon: Icons.arrow_forward_rounded,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SCREEN 3: Level Selection ───────────────────────────────────────

  Widget _buildLevelPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // Title
              const Text(
                'Your level?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Don\'t worry, you can change this later',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),

              const SizedBox(height: 36),

              // Level options
              ...List.generate(_levelOptions.length, (index) {
                final option = _levelOptions[index];
                final isSelected = _selectedLevel == option.label;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildLevelCard(
                    option: option,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedLevel = option.label);
                    },
                  ),
                );
              }),

              const Spacer(flex: 2),

              // Continue button
              _buildPrimaryButton(
                label: 'Continue',
                onTap: _selectedLevel != null ? _goToNextPage : null,
                icon: Icons.arrow_forward_rounded,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SCREEN 4: Daily Goal ────────────────────────────────────────────

  Widget _buildDailyGoalPage() {
    final List<Map<String, dynamic>> goalOptions = [
      {'minutes': 5, 'emoji': '☕', 'label': '5 min', 'desc': 'Quick & easy'},
      {'minutes': 10, 'emoji': '⚡', 'label': '10 min', 'desc': 'Recommended'},
      {'minutes': 15, 'emoji': '🔥', 'label': '15 min', 'desc': 'Committed'},
      {'minutes': 20, 'emoji': '🏆', 'label': '20 min', 'desc': 'Intensive'},
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('⏱️', style: TextStyle(fontSize: 40)),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title
              const Text(
                'Daily practice goal?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'How many minutes can you practice each day?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),

              const SizedBox(height: 36),

              // Goal option cards – 2x2 grid
              Row(
                children: [
                  Expanded(
                    child: _buildDailyGoalCard(
                      goalOptions[0],
                      goalOptions[0]['minutes'] == _selectedDailyGoal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDailyGoalCard(
                      goalOptions[1],
                      goalOptions[1]['minutes'] == _selectedDailyGoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDailyGoalCard(
                      goalOptions[2],
                      goalOptions[2]['minutes'] == _selectedDailyGoal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDailyGoalCard(
                      goalOptions[3],
                      goalOptions[3]['minutes'] == _selectedDailyGoal,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Get Started button
              _buildPrimaryButton(
                label: 'Get Started',
                onTap: _selectedDailyGoal != null ? _completeOnboarding : null,
                icon: Icons.rocket_launch_rounded,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyGoalCard(Map<String, dynamic> option, bool isSelected) {
    final int minutes = option['minutes'];
    final bool isRecommended = minutes == 10;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedDailyGoal = minutes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.7)
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              option['emoji'],
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              option['label'],
              style: TextStyle(
                fontSize: 20,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isRecommended && !isSelected
                    ? Colors.white.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                option['desc'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isRecommended ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.white.withOpacity(isRecommended ? 0.9 : 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────────────

  Widget _buildOptionCard({
    required String label,
    required String emoji,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.6)
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Emoji
            Text(
              emoji,
              style: const TextStyle(fontSize: 28),
            ),

            const SizedBox(width: 16),

            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            // Check icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Color(0xFF1E3A8A),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard({
    required LevelOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? option.color.withOpacity(0.8)
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.color.withOpacity(0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Level emoji with colored background
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? option.color.withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  option.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Label & description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected ? option.color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? option.color
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
    required IconData icon,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: isEnabled
          ? () {
              HapticFeedback.mediumImpact();
              onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isEnabled ? null : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isEnabled
                    ? const Color(0xFF1E293B)
                    : Colors.white.withOpacity(0.4),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 22,
              color: isEnabled
                  ? const Color(0xFF1E293B)
                  : Colors.white.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
