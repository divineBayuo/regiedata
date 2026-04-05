import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _darkAppBar('Attendance History'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2),
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
                              color: Colors.white.withOpacity(0.07))),
                      child: Icon(Icons.history_rounded,
                          size: 52, color: Colors.white.withOpacity(0.2))),
                  SizedBox(height: 24),
                  Text(
                    'No attendance records found.',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your check-ins will appear here.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 14),
                  )
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
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final eventName = data['eventName'] ?? 'Attendance';
              final initial =
                  eventName.isNotEmpty ? eventName[0].toUpperCase() : 'A';

              return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_green, Color(0xFF16A34A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              '${date.day}/${date.month}/${date.year} '
                              '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 12),
                            )
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _green.withOpacity(0.2))),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: _green, size: 13),
                            SizedBox(width: 4),
                            Text('Present',
                                style: TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700))
                          ],
                        ),
                      )
                    ],
                  ));
            },
          );
        },
      ),
    );
  }

  AppBar _darkAppBar(String title) => AppBar(
      backgroundColor: _bg,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
      title: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.06),
        ),
      ));
}
