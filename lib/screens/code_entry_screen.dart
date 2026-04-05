import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class CodeEntryScreen extends StatefulWidget {
  const CodeEntryScreen({super.key});

  @override
  State<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends State<CodeEntryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text(
          'Enter Attendance Code',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            )),
      ),
      body: Stack(
        children: [
          // Ambient Glow
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _green.withOpacity(0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon display
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                              color: _surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _green.withOpacity(0.2), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: _green.withOpacity(0.1),
                                    blurRadius: 30,
                                    spreadRadius: 4)
                              ]),
                          child: const Icon(
                            Icons.pin_outlined,
                            size: 40,
                            color: _green,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Enter Session Code',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit PIN provided by your admin\nto mark your attendance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.4),
                              height: 1.6),
                        ),
                        const SizedBox(height: 36),

                        // Code input card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.07))),
                          child: Column(
                            children: [
                              // PIN label
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _green.withOpacity(0.2)),
                                    ),
                                    child: const Text('6-DIGIT PIN',
                                        style: TextStyle(
                                            color: _green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Input field
                              TextFormField(
                                controller: _codeController,
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '• • • • • •',
                                  hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.15),
                                      fontSize: 28,
                                      letterSpacing: 6),
                                  prefixIcon: Icon(
                                    Icons.qr_code_rounded,
                                    color: _green.withOpacity(0.6),
                                    size: 22,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.04),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 18),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: _green, width: 1.5),
                                  ),
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 6,
                                ),
                                cursorColor: _green,
                                keyboardType: TextInputType.number,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 10,
                                onFieldSubmitted: (_) => _submitCode(),
                                onChanged: (value) {
                                  _codeController.value = TextEditingValue(
                                    text: value.toUpperCase(),
                                    selection: _codeController.selection,
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Submit button
                              GestureDetector(
                                onTap: _isLoading ? null : _submitCode,
                                child: Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: _isLoading
                                        ? null
                                        : const LinearGradient(
                                            colors: [_green, _greenDark]),
                                    color: _isLoading
                                        ? Colors.white.withOpacity(0.05)
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _isLoading
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: _green.withOpacity(0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: _green, strokeWidth: 2),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.check_circle_outline,
                                                  color: Colors.white,
                                                  size: 18),
                                              SizedBox(width: 8),
                                              Text('Mark Attendance',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15)),
                                            ],
                                          ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Info tip
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                'The code is given to you by your admin at the start of each session.',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 12,
                                    height: 1.5),
                              ))
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          backgroundColor: _greenDark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      SnackBar(
        content: Text(message),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(10)),
      ),
    );
  }
}
