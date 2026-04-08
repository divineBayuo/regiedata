import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/screens/google_profile_completion_screen.dart';
import 'package:regie_data/screens/landing_page.dart';
import 'package:regie_data/screens/main_shell.dart';
import 'package:regie_data/screens/signinpage.dart';

// Theme tokens
const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class Signuppage extends StatefulWidget {
  const Signuppage({super.key});

  @override
  State<Signuppage> createState() => _SignuppageState();
}

class _SignuppageState extends State<Signuppage> {
  // Personal information
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _othernameController = TextEditingController();

  // Additional Details
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;

  // Organization information
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  // Contact information
  final TextEditingController _phonenumberController = TextEditingController();
  final TextEditingController _residenceController = TextEditingController();

  // Work/School information
  bool isWorking = false;
  bool isSchooling = false;
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _placeofworkController = TextEditingController();
  final TextEditingController _placeofschoolController =
      TextEditingController();
  final TextEditingController _courseofstudyController =
      TextEditingController();

  // Account information
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmpasswordController =
      TextEditingController();

  // role by default
  final String _selectedRole = 'user'; // user or admin

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn =
      GoogleSignIn(clientId: dotenv.env['FIREBASE_CLIENT_ID']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // email validation regex
  final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  // password validation regex
  final RegExp _passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

  @override
  void dispose() {
    for (final ctrl in [
      _surnameController,
      _firstnameController,
      _othernameController,
      _familyController,
      _departmentController,
      _phonenumberController,
      _residenceController,
      _occupationController,
      _placeofworkController,
      _placeofschoolController,
      _courseofstudyController,
      _emailController,
      _passwordController,
      _confirmpasswordController
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _green,
                onPrimary: Colors.white,
                surface: _surface,
                onSurface: Colors.white,
              ),
            ),
            child: child!);
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  bool _validate() {
    if (_firstnameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your first name and surname.');
      return false;
    }
    if (_selectedGender == null) {
      _showSnackBar('Please select your gender.');
      return false;
    }
    if (_selectedDateOfBirth == null) {
      _showSnackBar('Please select your date of birth.');
      return false;
    }
    final phone =
        _phonenumberController.text.trim().replaceAll(RegExp(r'[-\s]'), '');
    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number.');
      return false;
    }
    if (phone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showSnackBar('Phone number must be exactly 10 digits.');
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email address.');
      return false;
    }
    if (!_emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnackBar('Please enter a valid email address.');
      return false;
    }
    if (!_passwordRegex.hasMatch(_passwordController.text)) {
      _showSnackBar(
          'Password must be 8+ chars with upper, lower, number & special char.');
      return false;
    }
    if (_passwordController.text != _confirmpasswordController.text) {
      _showSnackBar('Passwords do not match.');
      return false;
    }
    if (isWorking && _placeofworkController.text.trim().isEmpty) {
      _showSnackBar('Please enter your place of work.');
      return false;
    }
    if (isSchooling && _placeofschoolController.text.trim().isEmpty) {
      _showSnackBar('Please enter your place of school.');
      return false;
    }
    return true;
  }

  Future<void> _signUpWithEmail() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      // Set display name
      String displayName =
          '${_firstnameController.text.trim()} ${_surnameController.text.trim()}';
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();

      // Save to firestore
      await _saveUserToFirestore(userCredential.user!.uid);

      // Navigate to landing page
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MainShell(
            initialIndex: 0,
            homeWidget: LandingPage(),
          ),
        ),
      );

      if (!mounted) return;
      // Navigate based on role
      navigateBasedOnRole(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Sign-up failed';

      if (e.code == 'weak-password') {
        message = 'The password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Account already exists for this email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      }

      _showSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserToFirestore(String uid) async {
    final cleanPhone =
        _phonenumberController.text.trim().replaceAll(RegExp(r'[\s-]'), '');

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': _emailController.text.trim(),
      'surname': _surnameController.text.trim(),
      'firstname': _firstnameController.text.trim(),
      'othername': _othernameController.text.trim().isEmpty
          ? null
          : _othernameController.text.trim(),
      'gender': _selectedGender,
      'date_of_birth': _selectedDateOfBirth,
      'phone_number': cleanPhone,
      'residence': _residenceController.text.trim().isEmpty
          ? null
          : _residenceController.text.trim(),
      'occupation': _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      'isWorking': isWorking,
      'isSchooling': isSchooling,
      'placeOfWork': isWorking ? _placeofworkController.text.trim() : null,
      'placeOfSchool':
          isSchooling ? _placeofschoolController.text.trim() : null,
      'courseOfStudy':
          isSchooling ? _courseofstudyController.text.trim() : null,
      'family': _familyController.text.trim().isEmpty
          ? null
          : _familyController.text.trim(),
      'department': _departmentController.text.trim().isEmpty
          ? null
          : _departmentController.text.trim(),
      'role': _selectedRole == 'admin' ? 'pending_admin' : 'user',
      'isApproved': _selectedRole == 'user',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Check if user has complete profile
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        // new user: go to profile completion
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GoogleProfileCompletionScreen(
              user: userCredential.user!,
              email: userCredential.user!.email!,
              displayName: userCredential.user!.displayName,
            ),
          ),
        );
      } else {
        // existing user: navigate based on role
        navigateBasedOnRole(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Google sign-up failed: $e');
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: -80,
            right: -80,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [_green, _greenDark]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/regie_splash.png',
                        width: 20,
                        height: 20,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join the Regie community',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Personal information
                    _sectionCard(
                        icon: Icons.person_outline,
                        title: 'Personal Information',
                        children: [
                          _field('First Name', _firstnameController, 'John',
                              isRequired: true),
                          _field('Surname', _surnameController, 'Doe',
                              isRequired: true),
                          _field('Other Name(s)', _othernameController,
                              'Kofi (Optional)'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(child: _genderDropdown()),
                              const SizedBox(width: 12),
                              Expanded(child: _dobPicker()),
                            ],
                          )
                        ]),
                    const SizedBox(height: 16),

                    // Contact Information
                    _sectionCard(
                      icon: Icons.phone_outlined,
                      title: 'Contact Information',
                      children: [
                        _phoneField(),
                        _field('Residence', _residenceController,
                            'Abeka-Lapaz (Optional)'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Work/School Info
                    _sectionCard(
                      icon: Icons.work_outlined,
                      title: 'Work & Education',
                      children: [
                        _field('Occupation', _occupationController,
                            'Engineer/Student (Optional)'),
                        _checkboxGroup(),
                        if (isWorking) ...[
                          const SizedBox(height: 12),
                          _field(
                            'Place of Work',
                            _placeofworkController,
                            'Ghana Ltd',
                            isRequired: true,
                          ),
                        ],
                        if (isSchooling) ...[
                          const SizedBox(height: 12),
                          _field(
                            'Place of School',
                            _placeofschoolController,
                            'KNUST',
                            isRequired: true,
                          ),
                          _field(
                            'Course of Study',
                            _courseofstudyController,
                            'Computer Science (Optional)',
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Organization Info
                    _sectionCard(
                      icon: Icons.business_outlined,
                      title: 'Organization Information',
                      children: [
                        const SizedBox(
                          height: 16,
                        ),
                        _field(
                          'Family',
                          _familyController,
                          'Truth (Optional)',
                        ),
                        _field(
                          'Department',
                          _departmentController,
                          'Media (Optional)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Authentication
                    _sectionCard(
                      icon: Icons.lock_outline,
                      title: 'Account Credentials',
                      children: [
                        _field(
                          'Email Address',
                          _emailController,
                          'your.email@example.com',
                          keyboardType: TextInputType.emailAddress,
                          isRequired: true,
                        ),
                        _passwordField(
                          'Password',
                          _passwordController,
                          _obscurePassword,
                          () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          '8+ characters, upper, lower, number & special char',
                          isRequired: true,
                        ),
                        _passwordField(
                          'Confirm Password',
                          _confirmpasswordController,
                          _obscureConfirmPassword,
                          () => setState(() => _obscureConfirmPassword =
                              !_obscureConfirmPassword),
                          'Re-enter Password',
                          isRequired: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Create-account button
                    _primaryButton(
                      label: 'Create Account',
                      onTap: _isLoading ? null : _signUpWithEmail,
                    ),
                    const SizedBox(height: 20),

                    // Or Divider
                    _orDivider('or sign up with'),
                    const SizedBox(height: 20),

                    // Google sign-up
                    _googleButton(
                      label: 'Sign Up with Google',
                      onTap: _isLoading ? null : _signUpWithGoogle,
                    ),
                    const SizedBox(height: 24),

                    // Already have an account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Signinpage()),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _green,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: const Center(
                child: CircularProgressIndicator(
                  color: _green,
                  strokeWidth: 2.5,
                ),
              ),
            )
        ],
      ),
    );
  }

  // Section card wrapper
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: _green, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // Form fields
  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: _green, fontSize: 12),
          )
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    List<TextInputFormatter>? formatters,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _green,
      decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
          helperText: helper,
          helperStyle:
              TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _green, width: 1.5),
          )),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Column(
      children: [
        _label(label, required: isRequired),
        const SizedBox(height: 6),
        _input(controller: controller, hint: hint, keyboardType: keyboardType),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _phoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Phone Number', required: true),
        const SizedBox(height: 6),
        _input(
          controller: _phonenumberController,
          hint: '0244123456',
          keyboardType: TextInputType.phone,
          helper: 'Enter 10 digits only',
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggle,
    String hint, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: isRequired),
        const SizedBox(height: 6),
        _input(
          controller: controller,
          hint: hint,
          obscure: obscureText,
          suffix: IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.35),
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _genderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Gender', required: true),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          dropdownColor: _surface,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          iconEnabledColor: Colors.white.withOpacity(0.4),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _green),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
          ],
          onChanged: (v) => setState(() => _selectedGender = v),
        ),
      ],
    );
  }

  Widget _dobPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Date of Birth', required: true),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDateOfBirth == null
                      ? 'Select'
                      : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                  style: TextStyle(
                    color: _selectedDateOfBirth == null
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Icon(Icons.calendar_today_outlined,
                    color: Colors.white.withOpacity(0.3), size: 16),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _checkboxGroup() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          _styledCheckbox(
            'I am currently working',
            isWorking,
            (v) => setState(() => isWorking = v ?? false),
          ),
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          _styledCheckbox(
            'I am currently schooling',
            isSchooling,
            (v) => setState(() => isSchooling = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _styledCheckbox(
      String label, bool value, void Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(
        label,
        style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500),
      ),
      value: value,
      activeColor: _green,
      checkColor: Colors.white,
      side: BorderSide(color: Colors.white.withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onChanged: onChanged,
      dense: true,
    );
  }

  // Shared action widgets
  Widget _primaryButton({required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_green, _greenDark]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _orDivider(String text) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          ),
        ),
        Expanded(
            child: Divider(
          color: Colors.white.withOpacity(0.8),
        ))
      ],
    );
  }

  Widget _googleButton({required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/google_logo.png', width: 22, height: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }
}
