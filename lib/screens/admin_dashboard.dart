import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:regie_data/screens/all_attendance_screen.dart';
import 'package:regie_data/screens/manage_users_screen.dart';
import 'package:regie_data/screens/signinpage.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _totalUsers = 0;
  int _totalAttendance = 0;
  int _todayAttendance = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Get total users
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    // Get total attendance
    QuerySnapshot attendanceSnapshot =
        await _firestore.collection('attendance').get();

    // Get today's attendance
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    QuerySnapshot todaySnapshot = await _firestore
        .collection('attendance')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    setState(() {
      _totalUsers = usersSnapshot.docs.length;
      _totalAttendance = attendanceSnapshot.docs.length;
      _todayAttendance = todaySnapshot.docs.length;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const Signinpage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin welcome
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.green, Colors.lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 4,
                  ),
                  Text(
                    'Manage attendance and users',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Users',
                    _totalUsers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: _buildStatCard(
                    'Total Records',
                    _totalAttendance.toString(),
                    Icons.check_circle,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            _buildWideStatCard(
              'Today\'s Attendance',
              _todayAttendance.toString(),
              Icons.today,
              Colors.orange,
            ),

            const SizedBox(
              height: 24,
            ),

            // Admin Actions
            Text(
              'Admin Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(
              height: 16,
            ),

            _buildActionButton(
              'Create QR Code',
              'Generate QR code for attendance',
              Icons.qr_code,
              Colors.green,
              () => _showCreateQRDialog(context),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildActionButton(
              'View All Attendance',
              'See all attendance records',
              Icons.list_alt,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllAttendanceScreen(),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildActionButton(
              'Manage Users',
              'View and manage user accounts',
              Icons.people_outline,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageUsersScreen(),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildActionButton(
              'Analytics',
              'View attendance statistics',
              Icons.analytics,
              Colors.orange,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Analytics coming soon!'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(
            height: 12,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 40,
          ),
          const SizedBox(
            width: 16,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          )
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(
              width: 16,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  )
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateQRDialog(BuildContext context) {
    TextEditingController eventNameController = TextEditingController();
    String generatedCode = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Attendance Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eventNameController,
                decoration: const InputDecoration(
                  labelText: 'Event Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              if (generatedCode.isNotEmpty) ...[
                const Text('QR Code:'),
                const SizedBox(
                  height: 8,
                ),
                QrImageView(
                  data: generatedCode,
                  version: QrVersions.auto,
                  size: 200,
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Code: $generatedCode',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (eventNameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter event name'),
                    ),
                  );
                  return;
                }

                // Generate unique code
                String code = DateTime.now()
                    .millisecondsSinceEpoch
                    .toString()
                    .substring(7);

                // Save to Firestore
                await _firestore.collection('attendance_sessions').add({
                  'code': code,
                  'eventName': eventNameController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                  'active': true,
                });

                setDialogState(() {
                  generatedCode = code;
                });
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}
