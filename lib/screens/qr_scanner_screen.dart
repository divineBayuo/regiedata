import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:regie_data/helper_functions/organization_context.dart';

// const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;

  // Pulse animation for the scan frame
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = size.width < 400 ? 240.0 : 280.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.8)),
        title: const Text('Scan QR Code',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        actions: [
          // Torch toggle
          GestureDetector(
            onTap: () {
              cameraController.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _torchOn
                    ? const Color(0xFFF59E0B).withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _torchOn
                      ? const Color(0xFFF59E0B).withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn
                    ? const Color(0xFFF59E0B)
                    : Colors.white.withOpacity(0.5),
                size: 20,
              ),
            ),
          ),

          // Camera switch
          GestureDetector(
            onTap: () => cameraController.switchCamera(),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(Icons.cameraswitch_rounded,
                  color: Colors.white.withOpacity(0.5), size: 20),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
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
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: frameSize,
                    height: frameSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              ],
            ),
          ),

          // Animated scan frame
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Container(
                width: frameSize,
                height: frameSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _green.withOpacity(_pulseAnim.value),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _green.withOpacity(_pulseAnim.value * 0.025),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            ),
          ),

          // Corner accents
          Center(
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: CustomPaint(
                painter: _CornerPainter(frameSize),
              ),
            ),
          ),

          // Processing Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: _green, strokeWidth: 2.5),
                      const SizedBox(height: 16),
                      Text('Processing...',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

          // Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('Align QR code within the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The code will be scanned automatically',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _processQRCode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Vibrate on scan
      HapticFeedback.vibrate();

      // Get current user's organization
      String? orgId = await OrganizationContext.getCurrentOrganizationId();

      // Verify the code exists and belongs to user's organization in Firestore
      QuerySnapshot sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('code', isEqualTo: code)
          .where('organizationId', isEqualTo: orgId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        if (!mounted) return;
        _showErrorDialog('Invalid Code', 'This QR code is invalid or expired.');
        setState(() => _isProcessing = false);
        return;
      }

      // Get session data
      final sessionData =
          sessionQuery.docs.first.data() as Map<String, dynamic>;
      final eventName = sessionData['eventName'] ?? 'Attendance';

      // Check if user already marked attendance for this session
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        _showErrorDialog(
            'Not Signed In', 'You must be logged in to mark attendance.');
        setState(() => _isProcessing = false);
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
        _showErrorDialog('Already Checked In',
            'You have already marked attendance for this event.');
        setState(() => _isProcessing = false);
        return;
      }

      // Mark attendance
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': user.uid,
        'sessionId': sessionQuery.docs.first.id,
        'organizationId': orgId,
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
          backgroundColor: _greenDark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error', 'Failed to mark attendance: ${e.toString()}');
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 14),
              Text(message,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      height: 1.6)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _isProcessing = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Corner accent painter for the scan frame
class _CornerPainter extends CustomPainter {
  final double size;
  _CornerPainter(this.size);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = _green
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLen = 28.0;
    const r = 16.0;
    final w = canvasSize.width;
    final h = canvasSize.height;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(cornerLen, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, cornerLen), paint);

    // Top-right
    canvas.drawLine(Offset(w - cornerLen, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, cornerLen), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - cornerLen), Offset(0, h - r), paint);
    canvas.drawLine(Offset(r, h), Offset(cornerLen, h), paint);

    // Bottom-right
    canvas.drawLine(Offset(w, h - cornerLen), Offset(w, h - r), paint);
    canvas.drawLine(Offset(w - cornerLen, h), Offset(w - r, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
