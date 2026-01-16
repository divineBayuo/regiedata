import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              cameraController.value.torchState == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off,
              color: cameraController.value.torchState == TorchState.on
                  ? Colors.yellow
                  : Colors.white,
            ),
            onPressed: () {
              cameraController.toggleTorch();
              setState(() {});
            },
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Overlay with scanning frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Position the QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _processQRCode(String code) async {
    if (_isProcessing) return;
    setState(
      () {
        _isProcessing = true;
      },
    );

    try {
      // Vibrate on scan
      HapticFeedback.vibrate();

      // Verify the code exists in Firestore
      QuerySnapshot sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('code', isEqualTo: code)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        if (!mounted) return;
        _showErrorDialog(
            'Invalid Code', 'This QR code is innvalid or expired.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Get session data
      var sessionData = sessionQuery.docs.first.data() as Map<String, dynamic>;
      String eventName = sessionData['eventName'] ?? 'Attendance';

      // Check if user already marked attendance for this session
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        _showErrorDialog('Error', 'You must be logged in to mark attendance.');
        setState(() {
          _isProcessing = false;
        });
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
        if (!mounted) return;
        _showErrorDialog('Already Marked',
            'You have already marked attendance for this event.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Mark attendance
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': user.uid,
        'sessionId': sessionQuery.docs.first.id,
        'eventName': eventName,
        'timestamp': FieldValue.serverTimestamp(),
        'markedVia': 'qr_code',
      });

      if (!mounted) return;

      // Show success and go back
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance marked for: $eventName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error', 'Failed to mark attendance: ${e.toString()}');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
