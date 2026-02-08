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
import 'package:regie_data/screens/signinpage.dart';
import 'package:share_plus/share_plus.dart';

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
  int _activeSessions = 0;
  int _totalOrgMembers = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();
    if (orgId == null) {
      _showSnackBar('No organization selected');
      return;
    }

    // Get organization members count
    QuerySnapshot membersSnapshot = await _firestore
        .collection('organization_members')
        .where('organizationId', isEqualTo: orgId)
        .get();

    // Get total attendance for this org
    QuerySnapshot attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('organizationId', isEqualTo: orgId)
        .get();

    // Get total users
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    // Get today's attendance
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    QuerySnapshot todaySnapshot = await _firestore
        .collection('attendance')
        .where('organizationId', isEqualTo: orgId)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    // Get active sessions
    QuerySnapshot activeSessionsSnapshot = await _firestore
        .collection('attendance_sessions')
        .where('organizationId', isEqualTo: orgId)
        .where('active', isEqualTo: true)
        .get();

    setState(() {
      _totalUsers = usersSnapshot.docs.length;
      _totalAttendance = attendanceSnapshot.docs.length;
      _todayAttendance = todaySnapshot.docs.length;
      _activeSessions = activeSessionsSnapshot.docs.length;
      _totalOrgMembers = membersSnapshot.docs.length;
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
                  width: 8,
                ),
                Expanded(
                  child: _buildStatCard(
                    'Total Records',
                    _totalAttendance.toString(),
                    Icons.numbers_rounded,
                    Colors.red,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: _buildStatCard(
                    'Total Number of Members',
                    _totalOrgMembers.toString(),
                    Icons.check_circle,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child: _buildWideStatCard(
                    'Today\'s Attendance',
                    _todayAttendance.toString(),
                    Icons.today,
                    Colors.orange,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: _buildWideStatCard(
                    'Active Sessions',
                    _activeSessions.toString(),
                    Icons.event_available,
                    Colors.green,
                  ),
                )
              ],
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
              'Create Attendance Session',
              'Generate QR code and PIN for attendance',
              Icons.qr_code,
              Colors.green,
              () => _showCreateSessionDialog(context),
            ),

            const SizedBox(
              height: 12,
            ),

            _buildActionButton(
              'Active Sessions',
              'View and manage active attendance sessions',
              Icons.event_available,
              Colors.blue,
              () => _showActiveSessionsScreen(context),
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
              Colors.indigo,
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
              'Session History',
              'View past attendance sessions',
              Icons.history,
              Colors.teal,
              () => _showSessionHistoryScreen(context),
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
            size: 32,
          ),
          const SizedBox(
            width: 12,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

  void _showCreateSessionDialog(BuildContext parentContext) {
    final TextEditingController eventNameController = TextEditingController();
    final GlobalKey qrImageKey = GlobalKey(debugLabel: 'qr_image');

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
              title: const Text('Create Attendance Code'),
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
                            labelText: 'Event Name',
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
                            padding: const EdgeInsets.all(24),
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
                                const SizedBox(
                                  height: 16,
                                ),
                                const Text(
                                  'QR Code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.green, width: 2),
                                  ),
                                  child: QrImageView(
                                    data: generatedCode,
                                    version: QrVersions.auto,
                                    size: 200,
                                  ),
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    'PIN: $generatedCode',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 12,
                                ),
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
                        const SizedBox(
                          height: 16,
                        ),
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
                                    content: Text('PIN copied to clipboard!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.copy,
                                size: 18,
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
                                size: 18,
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
                    child: const Text('Generate'),
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
                        setState(
                          () {},
                        );
                        _loadStats();
                      }
                    },
                    child: const Text('Close Session'),
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
      // ALways refresh stats when dialog closes
      if (mounted) {
        setState(() {});
        _loadStats();
      }
    });
  }

  Future<void> _captureAndShareQR(BuildContext context, GlobalKey qrKey,
      String eventName, String code) async {
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
          content: Text('Error: ${e.toString()}'),
        ),
      );
    }
  }

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
                ));
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
                      SizedBox(
                        height: 16,
                      ),
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
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.event,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(data['eventName'] ?? 'Event'),
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
                                size: 150,
                              ),
                              const SizedBox(
                                height: 16,
                              ),

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
                              const SizedBox(
                                height: 16,
                              ),

                              // Real-time attendance count
                              StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('attendance')
                                    .where('sessionId', isEqualTo: doc.id)
                                    .snapshots(),
                                builder: (context, attendanceSnapshot) {
                                  int count = attendanceSnapshot.hasData
                                      ? attendanceSnapshot.data!.docs.length
                                      : 0;
                                  return Text(
                                    '$count attendees',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(
                                height: 16,
                              ),

                              // Close Session Button
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _firestore
                                      .collection('attendance_sessions')
                                      .doc(doc.id)
                                      .update({'active': false});

                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Session Closed'),
                                    ),
                                  );
                                  _loadStats();
                                },
                                icon: const Icon(Icons.close),
                                label: const Text('Close Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
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
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  bool isActive = data['active'] ?? false;
                  Timestamp? createdAt = data['createdAt'];

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
                      title: Text(data['eventName'] ?? 'Event'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PIN: ${data['code']}'),
                          if (createdAt != null)
                            Text(
                              'Created: ${_formatDate(createdAt.toDate())}',
                              style: const TextStyle(fontSize: 12),
                            ),
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

  void _showSnackBar(String message, {int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: duration),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return ('${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}');
  }
}
