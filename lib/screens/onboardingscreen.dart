import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:regie_data/screens/signinpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      asset: "assets/onboarding_analysis.json",
      title: "Welcome to Regie",
      description: "Your ultimate data management solution",
      buttonText: "Get Started",
    ),
    _OnboardPage(
      asset: "assets/onboarding_getthingsdone.json",
      title: "Track Attendance",
      description:
          "Seamlessly take attendance with a simple step-by-step process.",
      buttonText: "Continue",
    ),
    _OnboardPage(
      asset: "assets/onboarding_tracking.json",
      title: "Analyze Data",
      description: "Analyze and visualize your data with powerful tools.",
      buttonText: "Let's Begin",
    ),
  ];

  void _nextPage() async {
    print('Current page: $_currentPage, Total pages: ${_pages.length}');

    if (_currentPage == _pages.length - 1) {
      print('Last page reached, calling onFinish');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_time', false);

      if (!mounted) return;

      // Navigate directly instead of calling callback
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Signinpage()),
      );
    } else {
      print('Moving to next page');
      _pageController.nextPage(
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page);
                },
                itemCount: _pages.length,
                controller: _pageController,
                onPageChanged: (index) => setState(
                  () => _currentPage = index,
                ),
              ),
            ),
            _buildIndicator(),
            const SizedBox(
              height: 30,
            ),
            _buildButton(_pages[_currentPage]),
            const SizedBox(
              height: 40,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            page.asset,
            height: 240,
            repeat: true,
            fit: BoxFit.contain,
            animate: true,
          ),
          const SizedBox(
            height: 40,
          ),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade700, height: 1.4),
          )
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 16 : 8,
          height: _currentPage == index ? 12 : 8,
          decoration: BoxDecoration(
              color: _currentPage == index ? Colors.green : Colors.grey,
              shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildButton(_OnboardPage page) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        print('Button tapped on page: $_currentPage');
        _nextPage();
      },
      child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          height: 65,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                  colors: [Colors.green, Colors.lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: Center(
            child: Text(page.buttonText,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          )),
    );
  }
}

class _OnboardPage {
  final String asset;
  final String title;
  final String description;
  final String buttonText;

  _OnboardPage(
      {required this.asset,
      required this.title,
      required this.description,
      required this.buttonText});
}
