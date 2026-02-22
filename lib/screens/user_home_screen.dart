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
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && mounted) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          final firstname =
              userData['firstname'] ?? userData['firstName'] ?? '';
          final surname = userData['surname'] ?? '';
          _userName = '$firstname $surname'.trim();
          _userEmail = userData['email'];
        });
      }

      // Get total attendance count
      QuerySnapshot totalSnap = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Get this month attendance count
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      QuerySnapshot monthSnap = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      if (mounted) {
        setState(() {
          _attendanceCount = totalSnap.docs.length;
          _thisMonthCount = monthSnap.docs.length;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const Signinpage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _switchOrganization,
            icon: const Icon(Icons.business),
            tooltip: 'Switch Organization',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
            ).then((_) => _loadUserData()),
            icon: const Icon(Icons.person),
            tooltip: 'My Profile',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Colors.green, Colors.lightGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        _userName?.isNotEmpty == true
                            ? _userName![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back!',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(_userName ?? 'User',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            _userEmail ?? '',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats card
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                        'Total Attendance',
                        _attendanceCount.toString(),
                        Icons.check_circle,
                        Colors.blue),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: _buildStatCard(
                        'This Month',
                        _thisMonthCount.toString(),
                        Icons.calendar_month,
                        Colors.orange),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800),
              ),
              const SizedBox(height: 14),

              _buildActionButton(
                'Scan QR Code',
                'Scan to mark your attendance',
                Icons.qr_code_scanner,
                Colors.green,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const QRScannerScreen())),
              ),

              const SizedBox(height: 10),

              _buildActionButton(
                'Enter Code',
                'Type the sesssion PIN to check in',
                Icons.pin,
                Colors.blue,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CodeEntryScreen())),
              ),

              const SizedBox(height: 10),

              _buildActionButton(
                'Attendance History',
                'View all your attendance records',
                Icons.history,
                Colors.purple,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen())),
              ),

              const SizedBox(height: 10),

              _buildActionButton(
                'My Profile',
                'View and edit your personal details',
                Icons.person_outline,
                Colors.teal,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                ).then((_) => _loadUserData()),
              ),

              const SizedBox(height: 24),

              // Recent Attendance
              Text(
                'Recent Attendance',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800),
              ),

              const SizedBox(height: 14),

              _buildRecentAttendanceList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  )
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _switchOrganization() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const OrganizationSelectorScreen(),
      ),
    );
  }

  Widget _buildRecentAttendanceList() {
    return FutureBuilder<String?>(
      future: OrganizationContext.getCurrentOrganizationId(),
      builder: (context, orgSnapshot) {
        if (!orgSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final orgId = orgSnapshot.data;
        if (orgId == null) {
          return const Text('No organization selected');
        }

        final user = _auth.currentUser;
        if (user == null) return const Text('Not logged in');

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
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No attendance records yet'),
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

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['eventName'] ?? 'Attendance',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            )
                          ],
                        ),
                      ),
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
