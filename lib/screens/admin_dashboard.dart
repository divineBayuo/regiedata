import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/screens/all_attendance_screen.dart';
import 'package:regie_data/screens/manage_users_screen.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';
import 'package:regie_data/screens/signinpage.dart';
import 'package:share_plus/share_plus.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  int _totalAttendance = 0;
  int _todayAttendance = 0;
  int _activeSessions = 0;
  int _totalOrgMembers = 0;
  double _totalMoneyCollected = 0;

  // Monthly analytics: map of YYYY-MM -> total amount
  Map<String, double> _monthlyMoney = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();
    if (orgId == null) return;

    // Get organization members count
    final membersSnapshot = await _firestore
        .collection('organization_members')
        .where('organizationId', isEqualTo: orgId)
        .get();

    // Get total attendance for this org
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('organizationId', isEqualTo: orgId)
        .get();

    // Get today's attendance
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final todaySnapshot = await _firestore
        .collection('attendance')
        .where('organizationId', isEqualTo: orgId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    // Get active sessions
    final activeSessionsSnapshot = await _firestore
        .collection('attendance_sessions')
        .where('organizationId', isEqualTo: orgId)
        .where('active', isEqualTo: true)
        .get();

    // Fetch all sessions to compute money analytics
    final sessionsSnapshot = await _firestore
        .collection('attendance_sessions')
        .where('organizationId', isEqualTo: orgId)
        .get();

    double totalMoney = 0;
    Map<String, double> monthlyMoney = {};

    for (var doc in sessionsSnapshot.docs) {
      final data = doc.data();
      final money = (data['moneyCollected'] as num?)?.toDouble() ?? 0.0;
      if (money > 0) {
        totalMoney += money;
        final timestamp = data['createdAt'];
        DateTime date;
        if (timestamp is Timestamp) {
          date = timestamp.toDate();
        } else {
          date = DateTime.now();
        }
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        monthlyMoney[key] = (monthlyMoney[key] ?? 0) + money;
      }
    }

    // Sort the monthly map by key
    final sortedMonthly = Map.fromEntries(
      monthlyMoney.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    setState(() {
      _totalAttendance = attendanceSnapshot.docs.length;
      _todayAttendance = todaySnapshot.docs.length;
      _activeSessions = activeSessionsSnapshot.docs.length;
      _totalOrgMembers = membersSnapshot.docs.length;
      _totalMoneyCollected = totalMoney;
      _monthlyMoney = sortedMonthly;
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

  void _switchOrganization() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const OrganizationSelectorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _switchOrganization,
            icon: const Icon(Icons.business),
            tooltip: 'Switch Organization',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
                  size: 36,
                ),
                SizedBox(height: 10),
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'Manage attendance, members & finances',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stats Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Members',
                  _totalOrgMembers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Attendance Records',
                  _totalAttendance.toString(),
                  Icons.numbers,
                  Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Stats row 2
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today',
                  _todayAttendance.toString(),
                  Icons.today,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Active Sessions',
                  _activeSessions.toString(),
                  Icons.event,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Money Stat
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.teal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GH₵ ${_totalMoneyCollected.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total Money Collected',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Actions
          Text(
            'Admin Actions',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800),
          ),
          const SizedBox(height: 14),

          _buildActionButton(
            'Create Live Session',
            'Generate QR Code & PIN for attendance',
            Icons.qr_code,
            Colors.green,
            () => _showCreateSessionDialog(context),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            'Active Sessions',
            'View and manage currently active sessions',
            Icons.event_available,
            Colors.blue,
            () => _showActiveSessionsScreen(context),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            'View All Attendance',
            'See all attendance records',
            Icons.list_alt,
            Colors.purple,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AllAttendanceScreen())),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            'Manage Members',
            'View, edit & manage member accounts',
            Icons.people_outline,
            Colors.indigo,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            'Session History',
            'View all past attendance sessions',
            Icons.history,
            Colors.teal,
            () => _showSessionHistoryScreen(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Money Collected / Month',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800),
          ),
          const SizedBox(height: 16),
          if (_monthlyMoney.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No financial data yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record money collected when creating sessions',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildBarChart(),

          const SizedBox(height: 24),

          // Monthly breakdown table
          if (_monthlyMoney.isNotEmpty) ...[
            Text(
              'Monthly Breakdown',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: _monthlyMoney.entries.map((entry) {
                  final parts = entry.key.split('-');
                  final monthName = _monthName(int.parse(parts[1]));
                  final year = parts[0];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month,
                          color: Colors.teal, size: 20),
                    ),
                    title: Text('$monthName $year'),
                    trailing: Text(
                      'GH₵ ${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                          fontSize: 15),
                    ),
                  );
                }).toList(),
              ),
            )
          ],

          const SizedBox(height: 24),

          // Total summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.teal, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'All Time Collections',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  'GH₵ ${_totalMoneyCollected.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_monthlyMoney.isEmpty) return const SizedBox.shrink();

    final maxValue = _monthlyMoney.values.reduce((a, b) => a > b ? a : b);
    final entries = _monthlyMoney.entries.toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.map((entry) {
          final heightFraction = maxValue > 0 ? entry.value / maxValue : 0.0;
          final parts = entry.key.split('-');
          final monthLabel = _monthName(int.parse(parts[1])).substring(0, 3);
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'GH₵ ${entry.value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: (heightFraction * 130).clamp(4.0, 130.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.teal, Colors.green],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  parts[0].substring(2),
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                  ),
                )
              ],
            ),
          ));
        }).toList(),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[month];
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
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
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // Create Session Screen
  void _showCreateSessionDialog(BuildContext parentContext) {
    final TextEditingController eventNameController = TextEditingController();
    final GlobalKey qrImageKey = GlobalKey(debugLabel: 'qr_image');
    final moneyController = TextEditingController();

    String generatedCode = '';
    String sessionId = '';
    String eventName = '';

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Live Session'),
              content: SizedBox(
                width: 350,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (generatedCode.isEmpty) ...[
                        TextField(
                          controller: eventNameController,
                          decoration: const InputDecoration(
                            labelText: 'Session / Event Name *',
                            hintText:
                                'e.g., Monday Youth Service - Family Wars',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event),
                          ),
                        ),
                      ] else ...[
                        // Show generated session details
                        RepaintBoundary(
                          key: qrImageKey,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            color: Colors.white,
                            child: Column(
                              children: [
                                Text(
                                  eventName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'QR Code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.green, width: 2),
                                  ),
                                  child: QrImageView(
                                    data: generatedCode,
                                    version: QrVersions.auto,
                                    size: 180,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    'PIN: $generatedCode',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Scan QR or enter PIN to mark attendance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Share buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Copy button
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: generatedCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('PIN copied!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.copy,
                                size: 16,
                              ),
                              label: const Text('Copy PIN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            // Save/Share QR
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _captureAndShareQR(parentContext,
                                    qrImageKey, eventName, generatedCode);
                              },
                              icon: const Icon(
                                Icons.share,
                                size: 16,
                              ),
                              label: const Text('Share QR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                if (generatedCode.isEmpty) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final name = eventNameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter event name'),
                          ),
                        );
                        return;
                      }

                      final orgId =
                          await OrganizationContext.getCurrentOrganizationId();
                      if (orgId == null) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                              content: Text('No organization selected')),
                        );
                        return;
                      }

                      // Generate unique code
                      final code =
                          (Random().nextInt(900000) + 100000).toString();

                      // Parse optional money amount
                      double? money;
                      final moneyText = moneyController.text.trim();
                      if (moneyText.isNotEmpty) {
                        money = double.tryParse(moneyText);
                      }

                      // Save to Firestore
                      final docRef = await _firestore
                          .collection('attendance_sessions')
                          .add({
                        'code': code,
                        'eventName': name,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy': FirebaseAuth.instance.currentUser?.uid,
                        'active': true,
                        'organizationId': orgId,
                        if (money != null && money > 0) 'moneyCollected': money,
                      });

                      /* if (!context.mounted) return; */

                      setDialogState(() {
                        generatedCode = code;
                        sessionId = docRef.id;
                        eventName = name;
                      });

                      // Refresh stats
                      /* _loadStats(); */
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Create Session'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () async {
                      //Deactivate the session
                      await _firestore
                          .collection('attendance_sessions')
                          .doc(sessionId)
                          .update({'active': false});

                      if (!parentContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Session closed'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      if (mounted) {
                        setState(() {});
                        _loadStats();
                      }
                    },
                    child: const Text(
                      'End Session',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      // Refresh stats when dialog closes
                      if (mounted) {
                        setState(() {});
                        _loadStats();
                      }
                    },
                    child: const Text('Done'),
                  ),
                ],
              ],
            );
          },
        );
      },
    ).then((_) {
      eventNameController.dispose();
      moneyController.dispose();
      // ALways refresh stats when dialog closes
      if (mounted) {
        setState(() {});
        _loadStats();
      }
    });
  }

  Future<void> _captureAndShareQR(
    BuildContext context,
    GlobalKey qrKey,
    String eventName,
    String code,
  ) async {
    try {
      if (qrKey.currentContext == null) return;
      // Find render object
      final boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Capture the image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Use share_plus to share the image here
      await Share.shareXFiles(
        [XFile.fromData(pngBytes, name: 'qr_code.png', mimeType: 'image/png')],
        text: 'Attendance QR Code\nEvent: $eventName\nPIN: $code',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error Sharing: ${e.toString()}'),
        ),
      );
    }
  }

  // Active Sessions Screen
  void _showActiveSessionsScreen(BuildContext context) async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();
    if (orgId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Active Sessions'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('attendance_sessions')
                .where('organizationId', isEqualTo: orgId)
                .where('active', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print(snapshot.error);
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      )
                    ],
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Active Sessions',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final money = (data['moneyCollected'] as num?)?.toDouble();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.event,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(data['eventName'] ?? 'Session'),
                      subtitle: Text('PIN: ${data['code']}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // QR Code
                              QrImageView(
                                data: data['code'],
                                version: QrVersions.auto,
                                size: 140,
                              ),
                              const SizedBox(height: 14),

                              // monney display/edit
                              _buildMoneyEditor(doc.id, money),

                              const SizedBox(height: 12),

                              // Attendance count
                              StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('attendance')
                                    .where('sessionId', isEqualTo: doc.id)
                                    .snapshots(),
                                builder: (context, attSnap) {
                                  int count = attSnap.hasData
                                      ? attSnap.data!.docs.length
                                      : 0;
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      '$count attendees',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 14),

                              // PIN Display
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'PIN: ${data['code']}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: data['code']),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('PIN copied'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Action Buttons
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: data['code']));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('PIN copied')));
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy PIN'),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.blue,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await _firestore
                                          .collection('attendance_sessions')
                                          .doc(doc.id)
                                          .update({'active': false});

                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Session ended'),
                                        ),
                                      );
                                      _loadStats();
                                    },
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('End Session'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Money editor widget for active sessions
  Widget _buildMoneyEditor(String sessionId, double? currentMoney) {
    final controller =
        TextEditingController(text: currentMoney?.toStringAsFixed(2) ?? '');
    bool isEditing = false;

    return StatefulBuilder(
      builder: (context, setWidgetState) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.attach_money, color: Colors.teal, size: 18),
                  const SizedBox(width: 4),
                  if (!isEditing)
                    Text(
                      'GH₵ ${(currentMoney ?? 0).toStringAsFixed(2)} collected',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    )
                  else
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.all(8),
                          border: OutlineInputBorder(),
                          prefixText: 'GH₵ ',
                        ),
                        autofocus: true,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      if (isEditing) {
                        // Save
                        final newMoney = double.tryParse(controller.text);
                        if (newMoney != null) {
                          await _firestore
                              .collection('attendance_sessions')
                              .doc(sessionId)
                              .update({'moneyCollected': newMoney});
                          _loadStats();
                        }
                      }
                      setWidgetState(() => isEditing = !isEditing);
                    },
                    icon: Icon(isEditing ? Icons.check : Icons.edit, size: 18),
                    color: Colors.teal,
                    tooltip: isEditing ? 'Save' : 'Edit',
                  )
                ],
              ),
              if (isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Enter the amount and tap ✓ to save',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  // Session History Screen
  void _showSessionHistoryScreen(BuildContext context) async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();
    print('DEBUG: Current Org ID: $orgId');
    if (orgId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Session History'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('attendance_sessions')
                .where('organizationId', isEqualTo: orgId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              print('DEBUG: Connection state: ${snapshot.connectionState}');
              print('DEBUG: Has data: ${snapshot.hasData}');
              print('DEBUG: Doc count: ${snapshot.data?.docs.length}');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                print('DEBUG: Error: ${snapshot.error}');
                return const Center(
                  child: Text('No Sessions Found'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isActive = data['active'] ?? false;
                  final createdAt = data['createdAt'];
                  final money = (data['moneyCollected'] as num?)?.toDouble();

                  DateTime? date;
                  if (createdAt is Timestamp) date = createdAt.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green : Colors.grey,
                        child: Icon(
                          isActive ? Icons.event_available : Icons.event_busy,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(data['eventName'] ?? 'Session'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PIN: ${data['code']}'),
                          if (date != null)
                            Text(
                              '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (money != null && money > 0)
                            Text(
                              'GH₵ ${money.toStringAsFixed(2)} collected',
                              style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            )
                        ],
                      ),
                      trailing: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('attendance')
                            .where('sessionId', isEqualTo: doc.id)
                            .snapshots(),
                        builder: (context, attendanceSnapshot) {
                          int count = attendanceSnapshot.hasData
                              ? attendanceSnapshot.data!.docs.length
                              : 0;
                          return Chip(
                            label: Text('$count'),
                            backgroundColor: isActive
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
