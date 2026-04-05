import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);

class AllAttendanceScreen extends StatefulWidget {
  const AllAttendanceScreen({super.key});

  @override
  State<AllAttendanceScreen> createState() => _AllAttendanceScreenState();
}

class _AllAttendanceScreenState extends State<AllAttendanceScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _loadOrgId();
  }

  Future<void> _loadOrgId() async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();
    setState(() => _orgId = orgId);
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
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        backgroundColor: _bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Attendance Records',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            Text(
              'Admin view',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 11),
            )
          ],
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            )),
      ),
      body: _orgId == null
          ? const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('organizationId', isEqualTo: _orgId!)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _green, strokeWidth: 2),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: _surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Icon(
                            Icons.inbox_rounded,
                            size: 52,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No attendance records yet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Records will appear once members check in.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 14),
                        )
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(data['userId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        String userName = 'Unknown User';
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final ud =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          final fn = ud['firstName'] ?? ud['firstname'] ?? '';
                          final sn = ud['surname'] ?? '';
                          userName = '$fn $sn'.trim();
                          if (userName.isEmpty) userName = 'Unknown User';
                        }

                        final initial = userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : 'U';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: _green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _green.withOpacity(0.3))),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                        color: _green,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['eventName'] ?? 'Attendance',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12),
                                    ),
                                    Text(
                                      '${date.day}/${date.month}/${date.year} '
                                      '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11),
                                    )
                                  ],
                                ),
                              ),
                              // Delete
                              GestureDetector(
                                onTap: () =>
                                    _showDeleteConfirmation(context, doc.id),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.red.withOpacity(0.2)),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded,
                                      color: Colors.red.shade400, size: 18),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Delete Record',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16))
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete this attendance record?',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    height: 1.6),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.4)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await FirebaseFirestore.instance
                          .collection('attendance')
                          .doc(docId)
                          .delete();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _snack('Record deleted');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
