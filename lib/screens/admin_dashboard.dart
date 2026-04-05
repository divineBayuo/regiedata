import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/models/organization_model.dart';
import 'package:regie_data/screens/all_attendance_screen.dart';
import 'package:regie_data/screens/manage_users_screen.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';
import 'package:regie_data/screens/signinpage.dart';
import 'package:regie_data/services/organization_service.dart';
import 'package:share_plus/share_plus.dart';

// Theme tokens
const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

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

  final OrganizationService orgService = OrganizationService();
  final User? user = FirebaseAuth.instance.currentUser;

  OrganizationModel? _currentOrg;
  bool _isAdmin = false;

  // Monthly analytics: map of YYYY-MM -> total amount
  Map<String, double> _monthlyMoney = {};

  // Attendance analytics
  Map<String, int> _weeklyAttendance = {}; // YYYY-Www
  Map<String, int> _monthlyAttendance = {}; // YYYY-MM
  Map<String, int> _yearlyAttendance = {}; // YYYY

  // Analytics view toggle
  String _analyticsView = 'money'; //'money'/'attendance'
  String _attendancePeriod = 'month'; //'week'/'month'/'day'

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

    final orgDoc =
        await _firestore.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      final org = OrganizationModel.fromMap(orgDoc.data()!, orgDoc.id);

      final memberDoc = await _firestore
          .collection('organization_members')
          .where('organizationId', isEqualTo: orgId)
          .where('userId', isEqualTo: user?.uid)
          .limit(1)
          .get();

      bool isAdmin = false;
      if (memberDoc.docs.isNotEmpty) {
        final memberData = memberDoc.docs.first.data();
        isAdmin = memberData['role'] == 'admin';
      }

      setState(() {
        _currentOrg = org;
        _isAdmin = isAdmin;
      });
    }

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

    // Process attendance analytics
    Map<String, int> weeklyAtt = {};
    Map<String, int> monthlyAtt = {};
    Map<String, int> yearlyAtt = {};

    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'];
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();

        // Weekly (ISO week number)
        final weekKey = _getWeekKey(date);
        weeklyAtt[weekKey] = (weeklyAtt[weekKey] ?? 0) + 1;

        // Monthly
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        monthlyAtt[monthKey] = (monthlyAtt[monthKey] ?? 0) + 1;

        // Yearly
        final yearKey = '${date.year}';
        yearlyAtt[yearKey] = (yearlyAtt[yearKey] ?? 0) + 1;
      }
    }

    // Sort attendance maps
    final sortedWeeklyAtt = Map.fromEntries(weeklyAtt.entries.toList()
      ..sort(
        (a, b) => a.key.compareTo(b.key),
      ));
    final sortedMonthlyAtt = Map.fromEntries(monthlyAtt.entries.toList()
      ..sort(
        (a, b) => a.key.compareTo(b.key),
      ));
    final sortedYearlyAtt = Map.fromEntries(yearlyAtt.entries.toList()
      ..sort(
        (a, b) => a.key.compareTo(b.key),
      ));

    setState(() {
      _totalAttendance = attendanceSnapshot.docs.length;
      _todayAttendance = todaySnapshot.docs.length;
      _activeSessions = activeSessionsSnapshot.docs.length;
      _totalOrgMembers = membersSnapshot.docs.length;
      _totalMoneyCollected = totalMoney;
      _monthlyMoney = sortedMonthly;
      _monthlyAttendance = sortedMonthlyAtt;
      _weeklyAttendance = sortedWeeklyAtt;
      _yearlyAttendance = sortedYearlyAtt;
    });
  }

  String _getWeekKey(DateTime date) {
    final dayOfYear =
        int.parse("${date.difference(DateTime(date.year, 1, 1)).inDays + 1}");
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
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

  void _confirmDelete(BuildContext context, String orgId) {
    showDialog(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Delete Organization',
        icon: Icons.delete_forever_rounded,
        iconColor: Colors.red,
        content: Text(
          'This will permanently delete the organization and all its data. Are you sure you want to proceed?',
          style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
        ),
        actions: [
          _dialogTextBtn('Cancel', () => Navigator.pop(context)),
          _dialogBtn(
            label: 'Delete',
            color: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              try {
                await orgService.deleteOrganization(orgId);
                if (!mounted) return;
                _snack('Organization deleted.');
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OrganizationSelectorScreen()));
              } catch (e) {
                if (!mounted) return;
                _snack('Failed to delete: $e', error: true);
              }
            },
          )
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: _bg,
        elevation: 0,
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
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Divider(
                height: 1,
                color: Colors.white.withOpacity(0.06),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: _green,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: _green,
                unselectedLabelColor: Colors.white.withOpacity(0.35),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ],
          ),
        ),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2010), Color(0xFF0A1A0C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _green.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(color: _green.withOpacity(0.05), blurRadius: 30)
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _green.withOpacity(0.2)),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                              color: _green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage attendance, members & finances',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4), fontSize: 13),
                      )
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      color: _green, size: 28),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Row 1
          Row(
            children: [
              Expanded(
                  child: _statCard('Members', _totalOrgMembers.toString(),
                      Icons.people_outline, const Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard(
                      'Attendance Records',
                      _totalAttendance.toString(),
                      Icons.numbers_rounded,
                      const Color(0xFFEC4899)))
            ],
          ),
          const SizedBox(height: 12),

          // Stats row 2
          Row(
            children: [
              Expanded(
                  child: _statCard('Today', _todayAttendance.toString(),
                      Icons.today_outlined, const Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard('Live Sessions', _activeSessions.toString(),
                      Icons.wifi_tethering_rounded, _green)),
            ],
          ),

          const SizedBox(height: 12),

          // Money Stat
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF2DD4BF),
                    size: 24,
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
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5),
                    ),
                    Text(
                      'Total Money Collected',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Actions
          Text(
            'Quick Actions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 14),

          _actionBtn(
            'Create Live Session',
            'Generate QR Code & PIN for attendance',
            Icons.qr_code_rounded,
            _green,
            () => _showCreateSessionDialog(context),
          ),
          const SizedBox(height: 10),
          _actionBtn(
            'Active Sessions',
            'View and manage currently active sessions',
            Icons.wifi_tethering_rounded,
            const Color(0xFF3B82F6),
            () => _showActiveSessionsScreen(context),
          ),
          const SizedBox(height: 10),
          _actionBtn(
            'View All Attendance',
            'See all attendance records',
            Icons.list_alt_rounded,
            const Color(0xFFA855F7),
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AllAttendanceScreen())),
          ),
          const SizedBox(height: 10),
          _actionBtn(
            'Manage Members',
            'View, edit & manage member accounts',
            Icons.manage_accounts_outlined,
            const Color(0xFF6366F1),
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          ),
          const SizedBox(height: 10),
          _actionBtn(
            'Session History',
            'View all past attendance sessions',
            Icons.history,
            const Color(0xFF2DD4BF),
            () => _showSessionHistoryScreen(context),
          ),

          if (_isAdmin && _currentOrg != null) ...[
            const SizedBox(height: 28),
            Divider(color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.2))),
              child: const Text('DANGER ZONE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.red,
                      letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _confirmDelete(context, _currentOrg!.id),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delete Organization',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(
                              'Permanently remove this organization and all data',
                              style: TextStyle(
                                  color: Colors.red.withOpacity(0.5),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.red.withOpacity(0.4), size: 20),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ANALYTICS
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics type toggle
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _analyticsToggle(
                    'Money',
                    Icons.account_balance_wallet_rounded,
                    'money',
                  ),
                ),
                Expanded(
                  child: _analyticsToggle(
                    'Attendance',
                    Icons.people_outline,
                    'attendance',
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Show selected analytics
          if (_analyticsView == 'money')
            _buildMoneyAnalytics()
          else
            _buildAttendanceAnalytics(),
        ],
      ),
    );
  }

  Widget _analyticsToggle(String label, IconData icon, String value) {
    final isSelected = _analyticsView == value;
    return GestureDetector(
      onTap: () => setState(() => _analyticsView = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _green.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected ? Border.all(color: _green.withOpacity(0.3)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? _green : Colors.white.withOpacity(0.3),
                size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _green : Colors.white.withOpacity(0.3),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Money Collected / Month'),
        const SizedBox(height: 16),
        if (_monthlyMoney.isEmpty)
          _emptyBox(Icons.bar_chart_rounded, 'No financial data yet',
              'Record money when creating sessions')
        else
          _buildMoneyBarChart(),

        const SizedBox(height: 24),

        // Monthly breakdown table
        if (_monthlyMoney.isNotEmpty) ...[
          _sectionHeading('Monthly Breakdown', small: true),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: _monthlyMoney.entries.map((entry) {
                final parts = entry.key.split('-');
                final monthName = _monthName(int.parse(parts[1]));
                final year = parts[0];
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_outlined,
                        color: const Color(0xFF2DD4BF), size: 18),
                  ),
                  title: Text('$monthName $year'),
                  trailing: Text(
                    'GH₵ ${entry.value.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2DD4BF),
                        fontSize: 14),
                  ),
                );
              }).toList(),
            ),
          )
        ],

        const SizedBox(height: 24),

        // total summary
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), _greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grand Total',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'All Time Collection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                ],
              ),
              Text('GH₵ ${_totalMoneyCollected.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAttendanceAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period selector
        Row(
          children: [
            _sectionHeading('Attendance Trends'),
            const Spacer(),
            _periodChip('Week', 'week'),
            const SizedBox(width: 6),
            _periodChip('Month', 'month'),
            const SizedBox(width: 6),
            _periodChip('Year', 'year'),
          ],
        ),

        const SizedBox(height: 16),

        // Chart
        if (_getCurrentAttendanceData().isEmpty)
          _emptyBox(Icons.bar_chart_rounded, 'No attendaance data yet', '')
        else
          _buildAttendanceBarChart(),

        const SizedBox(height: 20),

        // Attendance stats cards
        Row(
          children: [
            Expanded(
              child: _attStat(
                'Total',
                _totalAttendance.toString(),
                Icons.people_outline,
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _attStat(
                'Average',
                _getAverageAttendance(),
                Icons.trending_up_rounded,
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _attStat(
                'Peak',
                _getPeakAttendance(),
                Icons.star_outline_rounded,
                const Color(0xFFA855F7),
              ),
            ),
          ],
        ),

        const SizedBox(width: 20),

        // Detailed breakdown
        if (_getCurrentAttendanceData().isNotEmpty) ...[
          _sectionHeading('Detailed Breakdown', small: true),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: _getCurrentAttendanceData().entries.map((entry) {
                return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.event_outlined,
                        color: Color(0xFF3B82F6),
                        size: 18,
                      ),
                    ),
                    title: Text(_formatPeriodLabel(entry.key),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ));
              }).toList(),
            ),
          )
        ]
      ],
    );
  }

  // Card & widget helpers
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
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
                TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
          )
        ],
      ),
    );
  }

  Widget _sectionHeading(String text, {bool small = false}) => Text(
        text,
        style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: small ? 14 : 16,
            fontWeight: FontWeight.w700),
      );

  Widget _emptyBox(IconData icon, String title, String sub) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 14),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.2), fontSize: 12),
              )
            ]
          ],
        ),
      );

  Widget _periodChip(String label, String value) {
    final isSelected = _attendancePeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _attendancePeriod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF3B82F6) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.35),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Dialog helpers
  Widget _darkDialog(
      {required String title,
      required IconData icon,
      required Color iconColor,
      required Widget content,
      required List<Widget> actions}) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map((a) => Padding(
                      padding: const EdgeInsets.only(left: 8), child: a))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _dialogTextBtn(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.4)),
        child: Text(label),
      );

  Widget _dialogBtn(
          {required String label,
          required Color color,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );

  // Utilities
  Map<String, int> _getCurrentAttendanceData() {
    switch (_attendancePeriod) {
      case 'week':
        return _weeklyAttendance;
      case 'year':
        return _yearlyAttendance;
      default:
        return _monthlyAttendance;
    }
  }

  String _formatPeriodLabel(String key) {
    if (_attendancePeriod == 'week') {
      final p = key.split('-W');
      return 'Week ${int.parse(p[1])}, ${p[0]}';
    } else if (_attendancePeriod == 'month') {
      final p = key.split('-');
      return '${_monthName(int.parse(p[1]))} ${p[0]}';
    }
    return key;
  }

  String _getShortLabel(String key) {
    if (_attendancePeriod == 'week') return 'W${int.parse(key.split('-W')[1])}';
    if (_attendancePeriod == 'month')
      return _monthName(int.parse(key.split('-')[1])).substring(0, 3);
    return "'${key.substring(2)}";
  }

  String _getAverageAttendance() {
    final data = _getCurrentAttendanceData();
    if (data.isEmpty) return '0';
    final total = data.values.reduce((a, b) => a + b);
    final avg = total / data.length;
    return avg.toStringAsFixed(0);
  }

  String _getPeakAttendance() {
    final data = _getCurrentAttendanceData();
    if (data.isEmpty) return '0';
    final peak = data.values.reduce((a, b) => a > b ? a : b).toString();
    return peak;
  }

  Widget _attStat(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(
            title,
            style:
                TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)),
          )
        ],
      ),
    );
  }

  Widget _buildAttendanceBarChart() {
    final data = _getCurrentAttendanceData();
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    final entries = data.entries.toList();

    // take last 12 entries max for better visualization
    final displayEntries =
        entries.length > 12 ? entries.sublist(entries.length - 12) : entries;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: displayEntries.map((entry) {
          final heightFraction = maxValue > 0 ? entry.value / maxValue : 0.0;
          final label = _getShortLabel(entry.key);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.4)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: (heightFraction * 110).clamp(4.0, 110.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.35)
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoneyBarChart() {
    if (_monthlyMoney.isEmpty) return const SizedBox.shrink();

    final maxValue = _monthlyMoney.values.reduce((a, b) => a > b ? a : b);
    final entries = _monthlyMoney.entries.toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                  style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.4)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: (heightFraction * 110).clamp(4.0, 110.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), _green],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  monthLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4)),
                ),
                Text(
                  parts[0].substring(2),
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white.withOpacity(0.2),
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

  Widget _actionBtn(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  )
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.2),
              size: 18,
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
            builder: (context, setDialogState) => Dialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: _green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.qr_code_rounded,
                                  color: _green, size: 20)),
                          const SizedBox(width: 12),
                          const Text('Create Live Sessions',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16))
                        ]),
                        const SizedBox(height: 20),
                        if (generatedCode.isEmpty) ...[
                          _dialogFieldLabel('Session / Event Name *'),
                          const SizedBox(height: 6),
                          _dialogTextField(
                              controller: eventNameController,
                              hint: 'e.g., Monday Youth Service',
                              icon: Icons.event_outlined),
                          const SizedBox(height: 14),
                          _dialogFieldLabel('Money Collected (optional)'),
                          const SizedBox(height: 6),
                          _dialogTextField(
                              controller: moneyController,
                              hint: '0.00',
                              icon: Icons.attach_money_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true)),
                        ] else ...[
                          // Show generated session details
                          RepaintBoundary(
                            key: qrImageKey,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                children: [
                                  Text(
                                    eventName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  QrImageView(
                                    data: generatedCode,
                                    version: QrVersions.auto,
                                    size: 180,
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text('PIN: $generatedCode',
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 3,
                                            color: Color(0xFF166534))),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Scan QR or enter PIN',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Share buttons
                          Row(
                            children: [
                              // Copy button
                              Expanded(
                                  child: _sessionBtn(
                                label: 'Copy PIN',
                                icon: Icons.copy_rounded,
                                color: Color(0xFF3B82F6),
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: generatedCode));
                                  _snack('PIN copied!');
                                },
                              )),
                              const SizedBox(width: 10),
                              // Save/Share QR
                              Expanded(
                                child: _sessionBtn(
                                  label: 'Share QR',
                                  icon: Icons.share_rounded,
                                  color: _green,
                                  onTap: () async {
                                    await _captureAndShareQR(parentContext,
                                        qrImageKey, eventName, generatedCode);
                                  },
                                ),
                              )
                            ],
                          )
                        ],
                        const SizedBox(height: 22),
                        Divider(color: Colors.white.withOpacity(0.06)),
                        const SizedBox(height: 14),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (generatedCode.isEmpty) ...[
                                _dialogTextBtn('Cancel',
                                    () => Navigator.pop(dialogContext)),
                                const SizedBox(width: 8),
                                _dialogBtn(
                                    label: 'Create Session',
                                    color: _green,
                                    onTap: () async {
                                      final name =
                                          eventNameController.text.trim();
                                      if (name.isEmpty) {
                                        _snack('Please enter event name');
                                        return;
                                      }
                                      final orgId = await OrganizationContext
                                          .getCurrentOrganizationId();
                                      if (orgId == null) {
                                        _snack('No organization selected');
                                        return;
                                      }
                                      final code =
                                          (Random().nextInt(900000) + 100000)
                                              .toString();
                                      double? money;
                                      if (moneyController.text
                                          .trim()
                                          .isNotEmpty) {
                                        money = double.tryParse(
                                            moneyController.text.trim());
                                      }
                                      final docRef = await _firestore
                                          .collection('attendance_sessions')
                                          .add({
                                        'code': code,
                                        'eventName': name,
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                        'createdBy': FirebaseAuth
                                            .instance.currentUser?.uid,
                                        'active': true,
                                        'organizationId': orgId,
                                        if (money != null && money > 0)
                                          'moneyCollected': money,
                                      });
                                      setDialogState(() {
                                        generatedCode = code;
                                        sessionId = docRef.id;
                                        eventName = name;
                                      });
                                    }),
                              ] else ...[
                                _dialogTextBtn('End Session', () async {
                                  await _firestore
                                      .collection('attendance_session')
                                      .doc(sessionId)
                                      .update({'active': false});
                                  if (!parentContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                  _snack('Session closed');
                                  if (mounted) {
                                    setState(() {});
                                    _loadStats();
                                  }
                                })
                              ]
                            ])
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).then((_) {
      eventNameController.dispose();
      moneyController.dispose();
      // ALways refresh stats when dialog closes
      if (mounted) {
        setState(() {});
        _loadStats();
      }
    });
  }

  Widget _dialogFieldLabel(String text) => Text(text,
      style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 12,
          fontWeight: FontWeight.w600));

  Widget _dialogTextField(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _green,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3), size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _green)),
      ),
    );
  }

  Widget _sessionBtn(
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13),
              )
            ],
          )),
    );
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

      DateTime date = DateTime.now();
      // Capture the image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Use share_plus to share the image here
      await Share.shareXFiles(
        [
          XFile.fromData(pngBytes,
              name: 'qr_code.png', mimeType: 'regi_attendance_$date/png')
        ],
        text: 'Attendance QR Code\nEvent: $eventName\nPIN: $code',
      );
    } catch (e) {
      if (!context.mounted) return;
      _snack('Error sharing: $e', error: true);
    }
  }

  // Active Sessions Screen
  void _showActiveSessionsScreen(BuildContext context) async {
    final orgId = await OrganizationContext.getCurrentOrganizationId();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: _bg,
          appBar: _darkAppBar('Active Sessions'),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('attendance_sessions')
                .where('organizationId', isEqualTo: orgId)
                .where('active', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                Logger().e(snapshot.error);
                return _errorWidget(snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: _green, strokeWidth: 2),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: _emptyBox(Icons.wifi_tethering_off_rounded,
                      'No Active Sessions', ''),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final money = (data['moneyCollected'] as num?)?.toDouble();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.07))),
                    child: Theme(
                      data: ThemeData.dark(),
                      child: ExpansionTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: _green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.event_outlined,
                              color: _green, size: 20),
                        ),
                        title: Text(data['eventName'] ?? 'Session',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Text('PIN: ${data['code']}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // QR Code
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: QrImageView(
                                    data: data['code'],
                                    version: QrVersions.auto,
                                    size: 140,
                                  ),
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
                                          color: _green.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: _green.withOpacity(0.2))),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.people_outline,
                                              color: _green, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$count attendee(s)',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: _green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 12),

                                // PIN Display
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'PIN: ${data['code']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: data['code']),
                                            );
                                            _snack('PIN copied');
                                          },
                                          icon: Icon(Icons.copy_rounded,
                                              color:
                                                  Colors.white.withOpacity(0.4),
                                              size: 18))
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: _sessionBtn(
                                        icon: Icons.copy_rounded,
                                        label: 'Copy PIN',
                                        color: const Color(0xFF3B82F6),
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(
                                              text: data['code']));
                                          _snack('PIN copied');
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _sessionBtn(
                                        icon: Icons.stop_circle_outlined,
                                        label: 'End Session',
                                        color: Colors.orange,
                                        onTap: () async {
                                          await _firestore
                                              .collection('attendance_sessions')
                                              .doc(doc.id)
                                              .update({'active': false});

                                          if (!context.mounted) return;
                                          _snack('Session ended');
                                          _loadStats();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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
              color: Color(0xFF2DD4BF).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.15))),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Color(0xFF2DD4BF), size: 16),
                  const SizedBox(width: 6),
                  if (!isEditing)
                    Text(
                      'GH₵ ${(currentMoney ?? 0).toStringAsFixed(2)} collected',
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    )
                  else
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF2DD4BF))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF2DD4BF))),
                            prefixText: 'GH₵ ',
                            prefixStyle: const TextStyle(
                                color: Color(0xFF2DD4BF), fontSize: 13)),
                        autofocus: true,
                      ),
                    ),
                  const SizedBox(width: 6),
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
                    icon: Icon(
                        isEditing ? Icons.check_rounded : Icons.edit_outlined,
                        size: 16),
                    color: Color(0xFF2DD4BF),
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
                      color: Colors.white.withOpacity(0.3),
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
    Logger().i('DEBUG: Current Org ID: $orgId');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: _darkAppBar('Session History'),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('attendance_sessions')
                .where('organizationId', isEqualTo: orgId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              Logger()
                  .e('DEBUG: Connection state: ${snapshot.connectionState}');
              Logger().e('DEBUG: Has data: ${snapshot.hasData}');
              Logger().e('DEBUG: Doc count: ${snapshot.data?.docs.length}');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: _green, strokeWidth: 2),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                Logger().e('DEBUG: Error: ${snapshot.error}');
                return Center(
                  child:
                      _emptyBox(Icons.history_rounded, 'No Sessions Found', ''),
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isActive
                                ? _green.withOpacity(0.2)
                                : Colors.white.withOpacity(0.06))),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _green.withOpacity(0.1)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                              isActive
                                  ? Icons.wifi_tethering_rounded
                                  : Icons.event_outlined,
                              color: isActive
                                  ? _green
                                  : Colors.white.withOpacity(0.3),
                              size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['eventName'] ?? 'Session',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text('PIN: ${data['code']}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 12)),
                            if (date != null)
                              Text(
                                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.2),
                                      fontSize: 11)),
                            if (money != null && money > 0)
                              Text('GH₵ ${money.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Color(0xFF2DD4BF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                          ],
                        )),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: isActive
                                        ? _green.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                      color: isActive
                                          ? _green
                                          : Colors.white.withOpacity(0.4),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                              );
                            })
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

  AppBar _darkAppBar(String title) => AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            )),
      );

  Widget _errorWidget(String error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text('ErrorL $error',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      );
}
