import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/screens/Signinpage.dart';
import 'package:regie_data/screens/main_shell.dart';
import 'package:regie_data/screens/user_home_screen.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);
const _amber = Color(0xFFF59E0B);

class PendingAdminScreen extends StatelessWidget {
  const PendingAdminScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
          pageBuilder: (_, __, ___) => const Signinpage(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 600;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_green, _greenDark]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/regie_splash.png',
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Regie',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 18),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _signOut(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Colors.white.withOpacity(0.5), size: 16),
                    const SizedBox(width: 6),
                    Text('Sign out',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 13))
                  ],
                ),
              ),
            ),
          )
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            )),
      ),
      body: Stack(
        children: [
          // Amber glow
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _amber.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 28,
                vertical: 48,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _amber.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _amber.withOpacity(0.12),
                            blurRadius: 40,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: const Icon(Icons.hourglass_empty_rounded,
                          size: 48, color: _amber),
                    ),

                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _amber.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'PENDING APPROVAL',
                        style: TextStyle(
                            color: _amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Admin Request\nUnder Review',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your request to become an admin is being reviewed by a super admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.5),
                          height: 1.65),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will be notified once the decision is made.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Column(
                        children: [
                          _infoRow(Icons.schedule_rounded, 'Review Time',
                              'Usually within 24-48 hours'),
                          const SizedBox(height: 14),
                          Divider(
                              color: Colors.white.withOpacity(0.06), height: 1),
                          const SizedBox(height: 14),
                          _infoRow(Icons.notifications_outlined, 'Notification',
                              'You\'ll see the update nect time you sign in'),
                          const SizedBox(height: 14),
                          Divider(
                              color: Colors.white.withOpacity(0.06), height: 1),
                          const SizedBox(height: 14),
                          _infoRow(Icons.people_outline, 'In the meantime',
                              'You can continue using the app as a regular member'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Continue as a user button
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MainShell(
                                  initialIndex: 0,
                                  homeWidget: UserHomeScreen(),
                                )),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_green, _greenDark]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Continue as Member',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Contact support button
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Contact your admin for assistance.'),
                            backgroundColor: _surface,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _amber.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Center(
                          child: Text(
                            'Contact Support',
                            style: TextStyle(
                                color: _amber,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _amber, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ],
          ),
        )
      ],
    );
  }
}
