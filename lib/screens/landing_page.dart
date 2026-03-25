import 'package:flutter/material.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _heroController;
  late AnimationController _pulseController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _pulse;

  // Section keys for nav scrolling
  final _featuresKey = GlobalKey();
  final _howItWorksKey = GlobalKey();
  final _pricingKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _heroController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  void _enterApp() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OrganizationSelectorScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildNav(context),
            _buildHero(context),
            _buildProblem(context),
            _buildFeatures(context),
            _buildHowItWorks(context),
            _buildPricing(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // NAVIGATION
  Widget _buildNav(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      color: const Color(0xFF0A0F0A),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          //Logo
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/regie_splash.png',
                  width: 45,
                  height: 45,
                  fit: BoxFit.fill,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Regie Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              )
            ],
          ),
          const Spacer(),
          if (isWide) ...[
            _navLink('Features', () => _scrollToKey(_featuresKey)),
            const SizedBox(width: 28),
            _navLink('How It Works', () => _scrollToKey(_howItWorksKey)),
            const SizedBox(width: 28),
            _navLink('Pricing', () => _scrollToKey(_pricingKey)),
            const SizedBox(width: 32),
          ],
          _ctaButton(
            label: 'Begin',
            onTap: _enterApp,
            small: true,
          )
        ],
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // HERO
  Widget _buildHero(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 700;

    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 80 : 28,
            vertical: isWide ? 96 : 64,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0F0A),
                Color(0xFF0D1A0F),
                Color(0xFF0A0F0A),
              ],
            ),
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _heroText(isWide)),
                    const SizedBox(width: 60),
                    Expanded(flex: 4, child: _heroCard()),
                  ],
                )
              : Column(
                  children: [
                    _heroText(isWide),
                    const SizedBox(height: 48),
                    _heroCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _heroText(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF22C55E).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: Color(0xFF22C55E), size: 14),
              SizedBox(width: 6),
              Text(
                'Smart Attendance for Modern Orgs',
                style: TextStyle(
                  color: Color(0xFF22C55E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Headline
        Text(
          'Attendance,\nSimplified.',
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 62 : 44,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Regie Data replaces paper registers and messy\nspreadsheets with QR codes, live sessions,\nand real-time analytics - all in one place.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: isWide ? 17 : 15,
            height: 1.7,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 40),

        // CTAs
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _ctaButton(label: 'Start for Free', onTap: _enterApp),
            GestureDetector(
              onTap: () => _scrollToKey(_howItWorksKey),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See How It Works',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_downward,
                        color: Colors.white.withOpacity(0.5), size: 16),
                  ],
                ),
              ),
            )
          ],
        ),

        const SizedBox(height: 52),

        // SOCIAL PROOF
        Row(
          children: [
            _miniStat('100+', 'Organizations'),
            _divider(),
            _miniStat('10k+', 'Records Tracked'),
            _divider(),
            _miniStat('99%', 'Uptime'),
          ],
        )
      ],
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        )
      ],
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: 1,
      height: 32,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _heroCard() {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF111811),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF22C55E).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.08),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Mock QR
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Fake QR grid
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: 100,
                      itemBuilder: (_, i) {
                        final pattern = [
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          1,
                          0,
                          0,
                          1,
                          1,
                          1,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          1,
                          0,
                          1,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          1,
                          1,
                          0,
                          0,
                          1,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          1,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          1,
                          0,
                          1,
                          0,
                          1,
                          0,
                          1,
                          0,
                          0,
                          0,
                          1,
                          1,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          1,
                          0,
                          1,
                          0,
                          0,
                          0,
                        ];
                        final isDark = pattern[i] == 0;
                        return Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF111811) : Colors.white,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // PIN display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.2),
                ),
              ),
              child: const Center(
                child: Text(
                  'PIN: 4 8 3 9 2 1',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniChip(Icons.people, '24 Present', const Color(0xFF22C55E)),
                _miniChip(Icons.access_time, 'Live', Colors.orange),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      ),
    );
  }

  // PROBLEM STATEMENT
  Widget _buildProblem(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 28,
        vertical: isWide ? 80 : 56,
      ),
      color: const Color(0xFF0D1A0F),
      child: Column(
        children: [
          _sectionBadge('The Problem'),
          const SizedBox(height: 20),
          Text(
            'Paper registers are\na thing of the past.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 40 : 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Churches, schools, and businesses still waste hours every week on manual attendance - messy notebooks, lost registers, and spreadsheets no one can read.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 52),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 3 : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _problemCard(
                    Icons.article_outlined,
                    'Lost Registers',
                    'Paper attendance sheets get lost, damaged, or impossible to archive.',
                    crossCount,
                    constraints.maxWidth,
                  ),
                  _problemCard(
                    Icons.schedule,
                    'Wasted Time',
                    'Calling names or passing sheets around eats into every session.',
                    crossCount,
                    constraints.maxWidth,
                  ),
                  _problemCard(
                    Icons.bar_chart_outlined,
                    'No Insights',
                    'You can\'t spot trends or see who\'s consistently absent without hours of minimal work.',
                    crossCount,
                    constraints.maxWidth,
                  ),
                ],
              );
            },
          )
        ],
      ),
    );
  }

  Widget _problemCard(IconData icon, String title, String desc, int crossCount,
      double totalWidth) {
    final itemWidth =
        crossCount > 1 ? (totalWidth - 32) / crossCount : double.infinity;
    return SizedBox(
      width: itemWidth,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111811),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.red.shade300, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 14,
                height: 1.6,
              ),
            )
          ],
        ),
      ),
    );
  }

  // FEATURES
  Widget _buildFeatures(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      key: _featuresKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 28,
        vertical: isWide ? 80 : 56,
      ),
      color: const Color(0xFF0A0F0A),
      child: Column(
        children: [
          _sectionBadge('Features'),
          const SizedBox(height: 20),
          Text(
            'Everything your\norganization needs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 40 : 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 2 : 1;
              final itemWidth = crossCount > 1
                  ? (constraints.maxWidth - 20) / crossCount
                  : double.infinity;
              final features = [
                _FeatureData(
                  Icons.qr_code_scanner,
                  'QR Code & PIN Sessions',
                  'Generate a live session in seconds. Members scan a QR code or enter a 6-digit PIN to mark their attendance instantly.',
                  const Color(0xFF22C55E),
                ),
                _FeatureData(
                  Icons.bar_chart,
                  'Real-Time Analytics',
                  'Track attendance trends by week, month or year. Spot patterns, identify absences, and get a full picture of your org.',
                  const Color(0xFF3B82F6),
                ),
                _FeatureData(
                  Icons.people_outline,
                  'Member Management',
                  'Add, edit and manage all members from one place. Assign roles and control who can do what in your organization.',
                  const Color(0xFFA855F7),
                ),
                _FeatureData(
                  Icons.attach_money,
                  'Financial Tracking',
                  'Record money collected per session and view monthly breakdowns - perfect for churches, clubs, and dues-collecting groups.',
                  const Color(0xFFF59E0B),
                ),
                _FeatureData(
                  Icons.share,
                  'Share & Export',
                  'Share QR codes via WhatsApp or any messaging app. Copy PINs with one tap. Always ready when your session starts.',
                  const Color(0xFF06B6D4),
                ),
                _FeatureData(
                  Icons.business,
                  'Multi-Organization',
                  'Manage multiple organizations from one account. Switch between them instantly without logging out.',
                  const Color(0xFFEC4899),
                ),
              ];
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: features
                    .map((f) => SizedBox(
                          width: itemWidth,
                          child: _featureCard(f),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _featureCard(_FeatureData f) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111811),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: f.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(f.icon, color: f.color, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            f.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            f.desc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 14,
              height: 1.65,
            ),
          )
        ],
      ),
    );
  }

  // HOW IT WORKS
  Widget _buildHowItWorks(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      key: _howItWorksKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 28, vertical: isWide ? 80 : 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1A0F),
            Color(0xFF0A0F0A),
          ],
        ),
      ),
      child: Column(
        children: [
          _sectionBadge('How It Works'),
          const SizedBox(height: 20),
          Text(
            'Up and running\nin three steps.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 40 : 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 56),
          LayoutBuilder(
            builder: (context, constraints) {
              final isRow = constraints.maxWidth > 700;
              final steps = [
                _StepData('01', 'Create or Join',
                    'Sign up and create your organization in seconds, or join an existing one with a code from your admin.'),
                _StepData('02', 'Start a Session',
                    'As admin, tap "Create Live Session," name the event, and instantly get a shareable QR code and PIN.'),
                _StepData('03', 'Members Check In',
                    'Members scan the QR code or enter the PIN on their phones. Attendance is recorded live, no paper needed.'),
              ];
              if (isRow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: steps
                      .asMap()
                      .entries
                      .map((e) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: e.key < steps.length - 1 ? 20 : 0),
                              child: _stepCard(e.value, isRow),
                            ),
                          ))
                      .toList(),
                );
              }
              return Column(
                children: steps
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _stepCard(s, isRow),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 56),
          _ctaButton(label: 'Get Started Free', onTap: _enterApp),
        ],
      ),
    );
  }

  Widget _stepCard(_StepData s, bool isRow) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111811),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.number,
            style: const TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          )
        ],
      ),
    );
  }

  // PRICING
  Widget _buildPricing(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      key: _pricingKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 28,
        vertical: isWide ? 80 : 56,
      ),
      color: const Color(0xFF0A0F0A),
      child: Column(
        children: [
          _sectionBadge('Pricing'),
          const SizedBox(height: 20),
          Text(
            'Simple, transparent\npricing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 40 : 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start free. Scale when you\'re ready.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 52),
          LayoutBuilder(builder: (context, constraints) {
            final isRow = constraints.maxWidth > 700;
            final cards = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _pricingCard(
                  plan: 'Free',
                  price: 'GH₵ 0',
                  period: 'forever',
                  desc: 'Perfect for getting started.',
                  features: [
                    '1 Organization',
                    'Up to 30 members',
                    'Unlimited sessions',
                    '30-day attendance history',
                    'QR & PIN check-in',
                    'Basic analytics',
                  ],
                  isHighlighted: false,
                  onTap: _enterApp,
                )),
                const SizedBox(width: 20),
                Expanded(
                    child: _pricingCard(
                  plan: 'Pro',
                  price: 'GH₵ 49',
                  period: 'per month',
                  desc: 'For growing organizations.',
                  features: [
                    'Up to 5 Organizations',
                    'Unlimited members',
                    'Full attendance history',
                    'Advanced analytics',
                    'Financial tracking',
                    'CSV export',
                    'Priority support',
                  ],
                  isHighlighted: true,
                  badge: 'Most Popular',
                  onTap: _enterApp,
                )),
                const SizedBox(width: 20),
                Expanded(
                    child: _pricingCard(
                  plan: 'Business',
                  price: 'GH₵ 120',
                  period: 'per month',
                  desc: 'For large institutions.',
                  features: [
                    'Unlimited Organizations',
                    'Unlimited members',
                    'Full analytics suite',
                    'Custom branding',
                    'Dedicated support',
                    'API access',
                    'Team management',
                  ],
                  isHighlighted: false,
                  onTap: _enterApp,
                )),
              ],
            );
            if (isRow) return cards;
            return Column(
              children: [
                _pricingCard(
                  plan: 'Free',
                  price: 'GH₵ 0',
                  period: 'forever',
                  desc: 'Perfect for getting started.',
                  features: [
                    '1 Organization',
                    'Up to 30 members',
                    'Unlimited sessions',
                    '30-day attendance history',
                    'QR & PIN check-in',
                    'Basic analytics',
                  ],
                  isHighlighted: false,
                  onTap: _enterApp,
                ),
                const SizedBox(width: 16),
                _pricingCard(
                  plan: 'Pro',
                  price: 'GH₵ 49',
                  period: 'per month',
                  desc: 'For growing organizations.',
                  features: [
                    'Up to 5 Organizations',
                    'Unlimited members',
                    'Full attendance history',
                    'Advanced analytics',
                    'Financial tracking',
                    'CSV export',
                    'Priority support',
                  ],
                  isHighlighted: true,
                  badge: 'Most Popular',
                  onTap: _enterApp,
                ),
                const SizedBox(width: 16),
                _pricingCard(
                  plan: 'Business',
                  price: 'GH₵ 120',
                  period: 'per month',
                  desc: 'For large institutions.',
                  features: [
                    'Unlimited Organizations',
                    'Unlimited members',
                    'Full analytics suite',
                    'Custom branding',
                    'Dedicated support',
                    'API access',
                    'Team management',
                  ],
                  isHighlighted: false,
                  onTap: _enterApp,
                ),
              ],
            );
          })
        ],
      ),
    );
  }

  Widget _pricingCard({
    required String plan,
    required String price,
    required String period,
    required String desc,
    required List<String> features,
    required bool isHighlighted,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFF22C55E).withOpacity(0.06)
            : const Color(0xFF111811),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF22C55E).withOpacity(0.4)
              : Colors.white.withOpacity(0.07),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                plan,
                style: TextStyle(
                  color: isHighlighted
                      ? const Color(0xFF22C55E)
                      : Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              ]
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ month',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 13,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1E2A1E), height: 1),
          const SizedBox(height: 20),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: isHighlighted
                          ? const Color(0xFF22C55E)
                          : Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      f,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? const Color(0xFF22C55E)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: isHighlighted
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: Text(
                  isHighlighted ? 'Get Started' : 'Choose Plan',
                  style: TextStyle(
                    color: isHighlighted
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // FOOTER
  Widget _buildFooter(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 28,
        vertical: 48,
      ),
      color: const Color(0xFF070C07),
      child: Column(
        children: [
          // Top row
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerBrand(),
                    const Spacer(),
                    _footerColumn('Product', [
                      'Features',
                      'How It Works',
                      'Pricing',
                      'Changelog',
                    ]),
                    const SizedBox(width: 60),
                    _footerColumn('Organization', [
                      'About',
                      'Privacy Policy',
                      'Terms of Service',
                      'Contact',
                    ]),
                    const SizedBox(width: 60),
                    _footerColumn('Support', [
                      'Help Center',
                      'Community',
                      'Status',
                      'Report a Bug',
                    ]),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerBrand(),
                    const SizedBox(height: 32),
                    _footerColumn('Product', [
                      'Features',
                      'How It Works',
                      'Pricing',
                      'Changelog'
                    ]),
                    const SizedBox(height: 24),
                    _footerColumn('Organization', [
                      'Privacy Policy',
                      'Terms of Service',
                      'Contact',
                    ]),
                    const SizedBox(width: 24),
                    _footerColumn('Support', [
                      'Help Center',
                      'Community',
                      'Status',
                      'Report a Bug',
                    ]),
                  ],
                ),

          const SizedBox(height: 48),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 24),

          // Bottom Row
          Row(
            children: [
              Text(
                '© ${DateTime.now().year} Regie. All rights reserved.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'Made with ♥ in Ghana | BayuoTech',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 13,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _footerBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Image.asset(
                'assets/images/regie_splash.png',
                width: 17,
                height: 17,
                fit: BoxFit.fill,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Regie Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: Text(
            'Smart attendance for organizations that move fast.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _enterApp,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Get Started →',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _footerColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                item,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 13,
                ),
              ),
            ))
      ],
    );
  }

  // SHARED WIDGETS
  Widget _sectionBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22C55E).withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF22C55E),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _ctaButton({
    required String label,
    required VoidCallback onTap,
    bool small = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 20 : 28,
          vertical: small ? 11 : 15,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 14 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// DATA CLASSES
class _FeatureData {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _FeatureData(this.icon, this.title, this.desc, this.color);
}

class _StepData {
  final String number;
  final String title;
  final String desc;
  const _StepData(this.number, this.title, this.desc);
}
