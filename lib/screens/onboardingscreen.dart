import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lottie/lottie.dart';
import 'package:regie_data/screens/Signinpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme tokens
const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      asset: "assets/onboarding_analysis.json",
      badge: "Welcome",
      title: "Welcome to\nRegie",
      description:
          "Your smart attendance and data management solution,\nbuilt for modern organizations.",
      buttonText: "Get Started",
    ),
    _OnboardPage(
      asset: "assets/onboarding_getthingsdone.json",
      badge: "Attendance",
      title: "Track Attendance\nin Seconds",
      description:
          "Generate a QR code or PIN, share it with members,\nand watch attendance mark itself in real time.",
      buttonText: "Continue",
    ),
    _OnboardPage(
      asset: "assets/onboarding_tracking.json",
      badge: "Analytics",
      title: "Understand\nYour Data",
      description:
          "Visualize trends by week, month or year.\nTrack your finances and spot patterns that help your org grow.",
      buttonText: "Let's Begin",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _goToSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Signinpage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _nextPage() async {
    Logger().e('Current page: $_currentPage, Total pages: ${_pages.length}');

    if (_currentPage == _pages.length - 1) {
      await _goToSignIn();
    } else {
      final isWide = MediaQuery.of(context).size.width > 700;

      if (isWide) {
        // Wide layout
        setState(() => _currentPage++);
        _fadeController.forward(from: 0);
      } else {
        // Marrow layout
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Background glow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              top: -60,
              left: _currentPage == 0
                  ? -60
                  : _currentPage == 1
                      ? size.width / 2 - 100
                      : size.width - 80,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _green.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Skip button, top-right, on last page
            if (_currentPage < _pages.length - 1)
              Positioned(
                top: 16,
                right: 24,
                child: GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('first_time', false);
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const Signinpage(),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                  },
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Main content
            isWide ? _buildWideLayout() : _buildNarrowLayout(),
          ],
        ),
      ),
    );
  }

  // Wide layout (web/tablet)
  Widget _buildWideLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left - animation
              Expanded(
                flex: 5,
                child: _buildAnimationCard(_pages[_currentPage]),
              ),
              const SizedBox(width: 56),
              // Right: text, controls
              Expanded(
                flex: 5,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBadge(_pages[_currentPage].badge),
                        const SizedBox(height: 20),
                        _buildTitle(_pages[_currentPage].title,
                            fontSize: 38, align: TextAlign.left),
                        const SizedBox(height: 16),
                        _buildDescription(_pages[_currentPage].description,
                            align: TextAlign.left),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            _buildIndicator(),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _buildButton(fullWidth: false),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Narrow layout - mobile
  Widget _buildNarrowLayout() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _pages.length,
          itemBuilder: (context, index) {
            final page = _pages[index];
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAnimationCard(page),
                  const SizedBox(height: 32),
                  _buildBadge(page.badge),
                  const SizedBox(height: 20),
                  _buildTitle(page.title,
                      fontSize: 30, align: TextAlign.center),
                  const SizedBox(height: 16),
                  _buildDescription(page.description, align: TextAlign.center),
                  const SizedBox(height: 40),
                  _buildIndicator(),
                  const SizedBox(height: 28),
                  _buildButton(fullWidth: true),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Shared widgets
  Widget _buildAnimationCard(_OnboardPage page) {
    return Container(
      width: double.infinity,
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.06),
            blurRadius: 48,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Lottie.asset(
        page.asset,
        repeat: true,
        fit: BoxFit.contain,
        animate: true,
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withOpacity(0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTitle(String title,
      {required double fontSize, required TextAlign align}) {
    return Text(
      title,
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.1,
        letterSpacing: -0.8,
      ),
    );
  }

  Widget _buildDescription(String desc, {required TextAlign align}) {
    return Text(
      desc,
      textAlign: align,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withOpacity(0.45),
        height: 1.65,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color:
                _currentPage == index ? _green : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(3),
            //borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({required bool fullWidth}) {
    final isLast = _currentPage == _pages.length - 1;
    final button = GestureDetector(
      onTap: _nextPage,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_green, _greenDark]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _pages[_currentPage].buttonText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLast
                  ? Icons.rocket_launch_rounded
                  : Icons.arrow_forward_rounded,
              color: Colors.white.withOpacity(0.85),
              size: 18,
            )
          ],
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// Data classes
class _OnboardPage {
  final String asset;
  final String badge;
  final String title;
  final String description;
  final String buttonText;

  _OnboardPage({
    required this.asset,
    required this.badge,
    required this.title,
    required this.description,
    required this.buttonText,
  });
}
