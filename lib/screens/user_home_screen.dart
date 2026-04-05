// Regular users can only register and view their own attendance

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/screens/attendance_history_screen.dart';
import 'package:regie_data/screens/code_entry_screen.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';
import 'package:regie_data/screens/qr_scanner_screen.dart';
import 'package:regie_data/screens/signinpage.dart';
import 'package:regie_data/screens/user_profile_screen.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userName;
  String? _userEmail;
  int _attendanceCount = 0;
  int _thisMonthCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists || !mounted) return;

    final userData = userDoc.data() as Map<String, dynamic>;
    final firstname = userData['firstname'] ?? userData['firstName'] ?? '';
    final surname = userData['surname'] ?? '';

    final totalSnap = await _firestore
        .collection('attendance')
        .where('userId', isEqualTo: user.uid)
        .get();

    final now = DateTime.now();
    final monthSnap = await _firestore
        .collection('attendance')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime(now.year, now.month, 1)))
        .get();

    if (mounted) {
      setState(() {
        _userName = '$firstname $surname'.trim();
        _userEmail = userData['email'];
        _attendanceCount = totalSnap.docs.length;
        _thisMonthCount = monthSnap.docs.length;
      });
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Signinpage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _switchOrganization() => Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const OrganizationSelectorScreen()));

  @override
  Widget build(BuildContext context) {
    final initial =
        _userName?.isNotEmpty == true ? _userName![0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
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
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: _bg,
        actions: [
          IconButton(
            onPressed: _switchOrganization,
            icon: Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white.withOpacity(0.55),
            ),
            tooltip: 'Switch Organization',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
            ).then((_) => _loadUserData()),
            icon: Icon(
              Icons.person_outline_rounded,
              color: Colors.white.withOpacity(0.55),
            ),
            tooltip: 'My Profile',
          ),
          IconButton(
            onPressed: _signOut,
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.white.withOpacity(0.55),
            ),
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: _green,
        backgroundColor: _surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0D2010), Color(0xFF0A1A0C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _green.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(color: _green.withOpacity(0.05), blurRadius: 30),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [_green, _greenDark]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: _green.withOpacity(0.3), blurRadius: 12)
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12),
                          ),
                          Text(
                            _userName ?? 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_userEmail != null)
                            Text(
                              _userEmail!,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats card
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                        'Total Attendance',
                        _attendanceCount.toString(),
                        Icons.check_circle_outline_rounded,
                        Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard('This Month', _thisMonthCount.toString(),
                        Icons.calendar_month_outlined, Color(0xFFF59E0B)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: -0.2),
              ),
              const SizedBox(height: 14),

              _actionButton(
                'Scan QR Code',
                'Scan to mark your attendance',
                Icons.qr_code_scanner_rounded,
                _green,
                () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QRScannerScreen()))
                    .then((_) => _loadUserData()),
              ),

              const SizedBox(height: 10),

              _actionButton(
                'Enter Code',
                'Type the sesssion PIN to check in',
                Icons.pin_outlined,
                Color(0xFF3B82F6),
                () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CodeEntryScreen()))
                    .then((_) => _loadUserData()),
              ),

              const SizedBox(height: 10),

              _actionButton(
                'Attendance History',
                'View all your attendance records',
                Icons.history_rounded,
                Color(0xFFA855F7),
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen())),
              ),

              const SizedBox(height: 10),

              _actionButton(
                'My Profile',
                'View and edit your personal details',
                Icons.manage_accounts_outlined,
                const Color(0xFF2DD4BF),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                ).then((_) => _loadUserData()),
              ),

              const SizedBox(height: 28),

              // Recent Attendance
              Text(
                'Recent Attendance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 14),
              _buildRecentAttendanceList(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---Widgets---

  Widget _actionButton(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.2), size: 18)
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style:
                TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
          )
        ],
      ),
    );
  }

  Widget _buildRecentAttendanceList() {
    return FutureBuilder<String?>(
      future: OrganizationContext.getCurrentOrganizationId(),
      builder: (context, orgSnapshot) {
        if (!orgSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: _green,
              strokeWidth: 2,
            ),
          );
        }

        final orgId = orgSnapshot.data;
        if (orgId == null) {
          return Text(
            'No organization selected',
            style:
                TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          );
        }

        final user = _auth.currentUser;
        if (user == null) return const SizedBox.shrink();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('attendance')
              .where('userId', isEqualTo: user.uid)
              .where('organizationId', isEqualTo: orgId)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: _green, strokeWidth: 2));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 36, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(height: 10),
                    Text('No attendance records yet'),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp?;
                final date = timestamp?.toDate() ?? DateTime.now();
                final eventName = data['eventName'] ?? 'Attendance';
                final initial =
                    eventName.isNotEmpty ? eventName[0].toUpperCase() : 'A';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _green.withOpacity(0.2))),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w800,
                                fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            Text(
                              '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.3)),
                            )
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded,
                            color: _green, size: 14),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
