import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';

class CodeEntryScreen extends StatefulWidget {
  const CodeEntryScreen({super.key});

  @override
  State<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends State<CodeEntryScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Attendance Code'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pin,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Enter Session Code',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit PIN provided by your admin.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'Enter code (e.g. 1234567)',
                prefixIcon: const Icon(
                  Icons.qr_code,
                  color: Colors.green,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade400, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              keyboardType: TextInputType.number,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              onSubmitted: (value) => _submitCode(),
              onChanged: (value) {
                _codeController.value = TextEditingValue(
                  text: value.toUpperCase(),
                  selection: _codeController.selection,
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'Mark Attendance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showSnackBar('Please enter a code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current user's organization
      String? orgId = await OrganizationContext.getCurrentOrganizationId();

      // Find an active session with this code in this org
      QuerySnapshot sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('code', isEqualTo: code)
          .where('organizationId', isEqualTo: orgId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        _showSnackBar('Invalid or expired code');
        setState(() => _isLoading = false);
        return;
      }

      // Get session data
      final sessionData =
          sessionQuery.docs.first.data() as Map<String, dynamic>;
      final eventName = sessionData['eventName'] ?? 'Attendance';

      // Check if user already marked attendance for this session
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('You must be logged in');
        setState(() => _isLoading = false);
        return;
      }

      // Check for duplicate attendance
      QuerySnapshot existingAttendance = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .where('sessionId', isEqualTo: sessionQuery.docs.first.id)
          .limit(1)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        _showSnackBar('You have already submitted attendance for this event');
        setState(() => _isLoading = false);
        return;
      }

      // Mark attendance
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': user.uid,
        'sessionId': sessionQuery.docs.first.id,
        'organizationId': orgId,
        'eventName': eventName,
        'timestamp': FieldValue.serverTimestamp(),
        'markedVia': 'code_entry',
      });

      if (!mounted) return;

      // Show success andd go back
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance marked for: $eventName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
