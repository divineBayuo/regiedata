import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regie_data/helper_functions/csv_download_web.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/screens/subscription_screen.dart';
import 'package:regie_data/services/subscription_service.dart';
import 'package:share_plus/share_plus.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

// Advanced Analytics Screen
// Shown as a full screen from admin dashboard
// All 6 sections are gated - free users see locked preview

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  bool _isLoading = true;
  String _userPlan = 'free';

  // -- data ---
  // 1. attendance rate per member: userId -> {name, rate, attended, total}
  List<_MemberRate> _memberRates = [];

  // 2. session performance: eventName -> attendeeCount
  Map<String, int> _sessionPerformance = {};

  // 3. Day-of-week heatmap: 1(Mon)..7(Sun) -> count
  Map<int, int> _dayOfWeek = {};

  // 4. Attendance rate over time: sessionLabel -> percent
  List<_SessionRate> _rateOverTime = [];

  // 5. Streaks: userId -> {name, currentStreak, bestStreak}
  List<_MemberStreak> _streaks = [];

  // 6. Financial per-session: sessionLabel -> {collected, attendees, perHead}
  List<_SessionFinancial> _financials = [];

  int _totalMembers = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userPlan = await SubscriptionService.getUserPlan(uid);
    }

    // only fetch heavy data for paid plans
    if (_userPlan != 'free') {
      await _fetchAdvancedData();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAdvancedData() async {
    final db = FirebaseFirestore.instance;
    final orgId = await OrganizationContext.getCurrentOrganizationId();
    if (orgId == null) return;

    // --fetch base data---
    final membersSnap = await db
        .collection('organization_members')
        .where('organizationId', isEqualTo: orgId)
        .get();

    final attendanceSnap = await db
        .collection('attendance')
        .where('organizationId', isEqualTo: orgId)
        .get();

    final sessionsSnap = await db
        .collection('attendance_sessions')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt')
        .get();

    _totalMembers = membersSnap.docs.length;

    // Build userId -> name map
    final nameMap = <String, String>{};
    for (final m in membersSnap.docs) {
      final userId = m['userId'] as String;
      try {
        final uDoc = await db.collection('users').doc(userId).get();
        if (uDoc.exists) {
          final d = uDoc.data()!;
          final fn = d['firstname'] ?? d['firstName'] ?? '';
          final sn = d['surname'] ?? '';
          nameMap[userId] =
              '$fn $sn'.trim().isEmpty ? 'Unknown' : '$fn $sn'.trim();
        }
      } catch (_) {}
    }

    // -- 1. Attendance Rate per Member
    final totalSessions = sessionsSnap.docs.length;
    final attendedByUser = <String, int>{};
    for (final a in attendanceSnap.docs) {
      final uid = a['userId'] as String? ?? '';
      if (uid.isNotEmpty) attendedByUser[uid] = (attendedByUser[uid] ?? 0) + 1;
    }

    _memberRates = membersSnap.docs.map((m) {
      final uid = m['userId'] as String;
      final attended = attendedByUser[uid] ?? 0;
      final rate = totalSessions > 0 ? (attended / totalSessions * 100) : 0.0;
      return _MemberRate(
        name: nameMap[uid] ?? 'Unknown',
        attended: attended,
        total: totalSessions,
        rate: rate.toDouble(),
      );
    }).toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));

    // --2. Session performance by event name
    final perfMap = <String, int>{};
    for (final a in attendanceSnap.docs) {
      final name = (a.data()['eventName'] as String?) ?? 'Unnamed';
      perfMap[name] = (perfMap[name] ?? 0) + 1;
    }
    _sessionPerformance = Map.fromEntries(
        perfMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    // --3. Day-of-week heatmap
    final dowMap = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    for (final a in attendanceSnap.docs) {
      final ts = a.data()['timestamp'] as Timestamp?;
      if (ts != null) {
        final dow = ts.toDate().weekday; // 1=Mon..7=Sun
        dowMap[dow] = (dowMap[dow] ?? 0) + 1;
      }
    }
    _dayOfWeek = dowMap;

    // --4. Attendance rate over time (last 20 sessions)
    final sessionsDocs =
        sessionsSnap.docs.reversed.take(20).toList().reversed.toList();
    final attendanceBySession = <String, int>{};
    for (final a in attendanceSnap.docs) {
      final sid = (a.data()['sessionId'] as String?) ?? '';
      if (sid.isNotEmpty) {
        attendanceBySession[sid] = (attendanceBySession[sid] ?? 0) + 1;
      }
    }

    _rateOverTime = sessionsDocs.map((s) {
      final count = attendanceBySession[s.id] ?? 0;
      final rate = _totalMembers > 0 ? (count / _totalMembers * 100) : 0.0;
      final ts = s.data()['createdAt'] as Timestamp?;
      final date = ts?.toDate();
      final label = date != null
          ? '${date.day}/${date.month}'
          : s.data()['eventName'] ?? '?';
      return _SessionRate(label: label, count: count, rate: rate.toDouble());
    }).toList();

    // --5. Attendance streaks
    // for each member, find consecutive sessions they attended
    final sortedSessions =
        sessionsSnap.docs.map((d) => d.id).toList(); // ordered by createdBy

    _streaks = [];
    for (final m in membersSnap.docs) {
      final uid = m['userId'] as String;
      final attended = <String>{};
      for (final a in attendanceSnap.docs) {
        if (a['userId'] == uid) {
          final sid = a.data()['sessionId'] as String? ?? '';
          attended.add(sid);
        }
      }

      int currentStreak = 0;
      int bestStreak = 0;
      int runningStreak = 0;
      // walk sessions newest-first for current streak
      for (int i = sortedSessions.length - 1; i >= 0; i--) {
        if (attended.contains(sortedSessions[i])) {
          runningStreak++;
          if (currentStreak == 0) currentStreak = runningStreak;
        } else {
          if (currentStreak == 0) currentStreak = 0; // broke before any
          break;
        }
      }
      // Walk all for best streak
      int tmp = 0;
      for (final sid in sortedSessions) {
        if (attended.contains(sid)) {
          tmp++;
          bestStreak = tmp > bestStreak ? tmp : bestStreak;
        } else {
          tmp = 0;
        }
      }

      _streaks.add(_MemberStreak(
        name: nameMap[uid] ?? 'Unknown',
        currentStreak: currentStreak,
        bestStreak: bestStreak,
      ));
    }
    _streaks.sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    // --6. Financial per session
    _financials = [];
    for (final s in sessionsSnap.docs) {
      final data = s.data();
      final money = (data['moneyCollected'] as num?)?.toDouble() ?? 0.0;
      if (money <= 0) continue;
      final count = attendanceBySession[s.id] ?? 0;
      final perHead = count > 0 ? money / count : 0.0;
      final ts = data['createdAt'] as Timestamp?;
      final date = ts?.toDate();
      _financials.add(_SessionFinancial(
        name: (data['eventName'] as String?) ?? 'Session',
        date: date,
        collected: money,
        attendees: count,
        perHead: perHead,
      ));
    }
    _financials.sort((a, b) => b.collected.compareTo(a.collected));
  }

  // -- CSV Export ---
  Future<void> exportAttendanceCsv(BuildContext context) async {
    try {
      final db = FirebaseFirestore.instance;
      final orgId = await OrganizationContext.getCurrentOrganizationId();
      if (orgId == null) return;

      // Show loading snacl
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preparing CSV...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));

      // Fetch all members for name lookup
      final membersSnap = await db
          .collection('organization_members')
          .where('organizationId', isEqualTo: orgId)
          .get();

      final nameMap = <String, String>{};
      for (final m in membersSnap.docs) {
        final uid = m['userId'] as String;
        try {
          final uDoc = await db.collection('users').doc(uid).get();
          if (uDoc.exists) {
            final d = uDoc.data()!;
            final fn = d['firstname'] ?? d['firstName'] ?? '';
            final sn = d['surname'] ?? '';
            nameMap[uid] = '$fn $sn'.trim().isEmpty ? uid : '$fn $sn'.trim();
          }
        } catch (_) {}
      }

      // Fetch all attendance
      final attSnap = await db
          .collection('attendance')
          .where('organizationId', isEqualTo: orgId)
          .orderBy('timestamp', descending: false)
          .get();

      // Build CSV
      final buffer = StringBuffer();
      buffer.writeln('Name,Event,Date,Time,Method');
      for (final doc in attSnap.docs) {
        final data = doc.data();
        final uid = data['userId'] as String? ?? '';
        final name = _csvEscape(nameMap[uid] ?? 'Unknown');
        final event = _csvEscape(data['eventName'] as String? ?? 'Attendance');
        final ts = data['timestamp'] as Timestamp?;
        final date = ts?.toDate();
        final dateStr = date != null
            ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
            : '';
        final timeStr = date != null
            ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
            : '';
        final method = _csvEscape(data['markedVia'] as String? ?? 'unknown');
        buffer.writeln('$name,$event,$dateStr,$timeStr,$method');
      }

      if (kIsWeb) {
        // trigger browser download on web
        downloadCsvWeb(buffer.toString(), 'regie_attendance.csv');
      } else {
        // Write to temp file
        final dir = await getTemporaryDirectory();
        //final file = File('${dir.path}/regie_attendance.csv');
        //await file.writeAsString(buffer.toString());

        final params = ShareParams(
          text: 'Regie Attendance Export',
          subject: 'Regie Attendance CSV',
          files: [XFile('${dir.path}/regie_attendance.csv')],
        );
        // Share
        await SharePlus.instance.share(params);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // --Build---

  @override
  Widget build(BuildContext context) {
    final isPaid = _userPlan == 'pro' || _userPlan == 'business';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white.withOpacity(0.7), size: 20),
        ),
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text('Advanced Analytics',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        actions: [
          // CSV Export - Pro/Business only
          if (isPaid)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => exportAttendanceCsv(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, color: _green, size: 15),
                      SizedBox(width: 6),
                      Text('CSV',
                          style: TextStyle(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              color: _green,
              backgroundColor: _surface,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gate header
                    if (!isPaid) _upgradeTeaser(),
                    if (!isPaid) const SizedBox(height: 20),

                    _sectionLabel('1. Attendance Rate per Member'),
                    const SizedBox(height: 12),
                    _PlanGateLocal(
                        plan: _userPlan,
                        feature: 'Attendance Rate per Member',
                        child: _buildMemberRates()),
                    const SizedBox(height: 24),

                    _sectionLabel('2. Session Performance'),
                    const SizedBox(height: 12),
                    _PlanGateLocal(
                        plan: _userPlan,
                        feature: 'Session Performance',
                        child: _buildSessionPerformance()),
                    const SizedBox(height: 24),

                    _sectionLabel('3. Day-of-Week Heatmap'),
                    const SizedBox(height: 12),
                    _PlanGateLocal(
                        plan: _userPlan,
                        feature: 'Day-of-Week Heatmap',
                        child: _buildDayHeatmap()),
                    const SizedBox(height: 24),

                    _sectionLabel('4. Attendance Rate Over Time'),
                    const SizedBox(height: 12),
                    _PlanGateLocal(
                        plan: _userPlan,
                        feature: 'Attendance Rate Over Time',
                        child: _buildRateOverTime()),
                    const SizedBox(height: 24),

                    _sectionLabel('5. Member Attendance Streaks'),
                    const SizedBox(height: 12),
                    _PlanGateLocal(
                        plan: _userPlan,
                        feature: 'Attendance Streaks',
                        child: _buildStreaks()),
                    const SizedBox(height: 24),

                    _sectionLabel('6. Financial Per-Session Breakdown'),
                    const SizedBox(height: 12),
                    _PlanGateLocal(
                        plan: _userPlan,
                        feature: 'Financial Breakdown',
                        child: _buildFinancials()),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // --section header---
  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 15,
            fontWeight: FontWeight.w700),
      );

  // --upgrade teaser
  Widget _upgradeTeaser() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_green.withOpacity(0.12), _green.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: _green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upgrade to Pro',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('Unlock all 6 advanced analytics features',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: _green, borderRadius: BorderRadius.circular(8)),
              child: const Text('Upgrade',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }

  // 1. Member attendance rates
  Widget _buildMemberRates() {
    if (_memberRates.isEmpty) {
      return _emptyCard('No member data available yet.');
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: _memberRates.take(10).map((m) {
          final color = m.rate >= 75
              ? _green
              : m.rate >= 50
                  ? const Color(0xFFF59E0B)
                  : Colors.red.shade400;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text('${m.rate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: m.rate / 100,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('${m.attended} of ${m.total} sessions',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (m != _memberRates.last && _memberRates.indexOf(m) < 9)
                  Divider(color: Colors.white.withOpacity(0.05), height: 16),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 2. session performance
  Widget _buildSessionPerformance() {
    if (_sessionPerformance.isEmpty) {
      return _emptyCard('No session data available yet.');
    }
    final maxVal = _sessionPerformance.values.reduce((a, b) => a > b ? a : b);
    final entries = _sessionPerformance.entries.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: entries.map((e) {
          final frac = maxVal > 0 ? e.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(e.key,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFA855F7)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${e.value}',
                    style: const TextStyle(
                        color: Color(0xFFA855F7),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 3. Day-of-week heatmap
  Widget _buildDayHeatmap() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = _dayOfWeek.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final count = _dayOfWeek[i + 1] ?? 0;
          final frac = maxVal > 0 ? count / maxVal : 0.0;
          final height = (frac * 80).clamp(4.0, 80.0);
          final color = frac > 0.7
              ? _green
              : frac > 0.4
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.12);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text('$count',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    days[i],
                    style: TextStyle(
                        fontSize: 10, color: Colors.white.withOpacity(0.4)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // 4. Attendance rate over time
  Widget _buildRateOverTime() {
    if (_rateOverTime.isEmpty) {
      return _emptyCard('No session data available yet.');
    }
    final maxRate =
        _rateOverTime.map((e) => e.rate).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('% of total members attending per session',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 11)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _rateOverTime.map((s) {
                final frac = maxRate > 0 ? s.rate / maxRate : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${s.rate.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 7,
                                color: Colors.white.withOpacity(0.35)),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: (frac * 80).clamp(4.0, 80.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(s.label,
                            style: TextStyle(
                                fontSize: 7,
                                color: Colors.white.withOpacity(0.3)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Streaks
  Widget _buildStreaks() {
    if (_streaks.isEmpty) {
      return _emptyCard('No attendance data available yet.');
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: _streaks.take(10).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    //Rank
                    SizedBox(
                      width: 24,
                      child: Text('${i + 1}.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    // Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: _green, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    // Current Streak
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: Color(0xFFF59E0B), size: 14),
                            const SizedBox(width: 3),
                            Text('${s.currentStreak}',
                                style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ],
                        ),
                        Text('Best: ${s.bestStreak}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 10)),
                      ],
                    )
                  ],
                ),
              ),
              if (i < _streaks.length - 1 && i < 9)
                Divider(color: Colors.white.withOpacity(0.05), height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 6. Financial per session
  Widget _buildFinancials() {
    if (_financials.isEmpty) {
      return _emptyCard('No financial data recorded yet.');
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                    child: Text('Session',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 70,
                    child: Text('Collected',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3), fontSize: 11),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 70,
                    child: Text('Per head',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3), fontSize: 11),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          ..._financials.take(10).map((f) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              if (f.date != null)
                                Text(
                                    '${f.date!.day}/${f.date!.month}/${f.date!.year} · ${f.attendees} attendees',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text('GHS${f.collected.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Color(0xFF2DD4BF),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                              textAlign: TextAlign.right),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text('GHS${f.perHead.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12),
                              textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.white.withOpacity(0.04), height: 1),
                ],
              )),
        ],
      ),
    );
  }

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(msg,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
      );
}

// plan gate (local, no stream needed - plan already loaded)
class _PlanGateLocal extends StatelessWidget {
  final String plan;
  final String feature;
  final Widget child;

  const _PlanGateLocal(
      {required this.plan, required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    final isPaid = plan == 'pro' || plan == 'business';
    if (isPaid) return child;

    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Opacity(opacity: 0.3, child: IgnorePointer(child: child))),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFF0A0F0A).withOpacity(0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          color: _green, size: 20),
                    ),
                    const SizedBox(height: 8),
                    const Text('Pro feature',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Tap to Upgrade',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF111811),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_green, _greenDark]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Upgrade to Pro',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 8),
              Text('"$feature" is a Pro feature. Starting at \$4.99/month.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.4)),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SubscriptionScreen()),
                        );
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: [_green, _greenDark]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('View Plans',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// data models
class _MemberRate {
  final String name;
  final int attended;
  final int total;
  final double rate;
  _MemberRate({
    required this.name,
    required this.attended,
    required this.total,
    required this.rate,
  });
}

class _SessionRate {
  final String label;
  final int count;
  final double rate;
  _SessionRate({
    required this.label,
    required this.count,
    required this.rate,
  });
}

class _MemberStreak {
  final String name;
  final int currentStreak;
  final int bestStreak;
  _MemberStreak({
    required this.name,
    required this.currentStreak,
    required this.bestStreak,
  });
}

class _SessionFinancial {
  final String name;
  final DateTime? date;
  final double collected;
  final int attendees;
  final double perHead;
  _SessionFinancial({
    required this.name,
    required this.date,
    required this.collected,
    required this.attendees,
    required this.perHead,
  });
}
