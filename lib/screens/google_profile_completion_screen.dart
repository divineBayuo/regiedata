import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/screens/landing_page.dart';

// Theme tokens
const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class GoogleProfileCompletionScreen extends StatefulWidget {
  final User user;
  final String email;
  final String? displayName;

  const GoogleProfileCompletionScreen({
    super.key,
    required this.user,
    required this.email,
    this.displayName,
  });

  @override
  State<GoogleProfileCompletionScreen> createState() =>
      _GoogleProfileCompletionScreenState();
}

class _GoogleProfileCompletionScreenState
    extends State<GoogleProfileCompletionScreen> {
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _othernameController = TextEditingController();
  final TextEditingController _phonenumberController = TextEditingController();
  final TextEditingController _residenceController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _placeofworkController = TextEditingController();
  final TextEditingController _placeofschoolController =
      TextEditingController();
  final TextEditingController _courseofstudyController =
      TextEditingController();
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  bool _isWorking = false;
  bool _isSchooling = false;
  bool _isLoading = false;
  String _selectedRole = 'user';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _prefillFromGoogle();
  }

  void _prefillFromGoogle() {
    // Prefill form with email and name where applicable
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      List<String> nameParts = widget.displayName!.split(' ');
      if (nameParts.isNotEmpty) {
        _firstnameController.text = nameParts.first;
      }
      if (nameParts.length > 1) {
        _surnameController.text = nameParts.last;
      }
    }
  }

  bool _validatePhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    return cleanPhone.length == 10 && RegExp(r'^\d{10}$').hasMatch(cleanPhone);
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
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              surface: _surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  Future<void> _completeProfile() async {
    // Validation
    if (_firstnameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your first name and surname');
      return;
    }

    if (_selectedGender == null) {
      _showSnackBar('Please select your gender');
      return;
    }

    if (_selectedDateOfBirth == null) {
      _showSnackBar('Please select your date of birth');
      return;
    }

    if (_phonenumberController.text.trim().isEmpty) {
      _showSnackBar('Please enter your phone number');
      return;
    }

    if (!_validatePhoneNumber(_phonenumberController.text.trim())) {
      _showSnackBar('Phone number must be exactly 10 digits');
      return;
    }

    if (_isWorking && _placeofworkController.text.trim().isEmpty) {
      _showSnackBar('Please enter your place of work');
      return;
    }

    if (_isSchooling && _placeofschoolController.text.trim().isEmpty) {
      _showSnackBar('Please enter your place of school');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String cleanPhone =
          _phonenumberController.text.trim().replaceAll(RegExp(r'[\s-]'), '');

      // Save complete profile to Firestore
      await _firestore.collection('users').doc(widget.user.uid).set({
        'uid': widget.user.uid,
        'email': widget.email,
        'firstName': _firstnameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'otherName': _othernameController.text.trim().isEmpty
            ? null
            : _othernameController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'phoneNumber': cleanPhone,
        'residence': _residenceController.text.trim().isEmpty
            ? null
            : _residenceController.text.trim(),
        'occupation': _occupationController.text.trim().isEmpty
            ? null
            : _occupationController.text.trim(),
        'isWorking': _isWorking,
        'isSchooling': _isSchooling,
        'placeOfWork': _isWorking ? _placeofworkController.text.trim() : null,
        'placeOfSchool':
            _isSchooling ? _placeofschoolController.text.trim() : null,
        'courseOfStudy':
            _isSchooling ? _courseofstudyController.text.trim() : null,
        'family': _familyController.text.trim().isEmpty
            ? null
            : _familyController.text.trim(),
        'department': _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        'role': _selectedRole == 'admin' ? 'admin' : 'user',
        'isApproved': _selectedRole == 'user',
        'createdAt': DateTime.now().toIso8601String(),
      });

      Logger().e('Profile saved to Firestore');

      if (!mounted) return;

      // Navigate to landing page
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LandingPage(),
        ),
      );

      if (!mounted) return;

      // Navigate based on role
      navigateBasedOnRole(context);
    } catch (e) {
      Logger().e('Error completing profile: $e');
      if (!mounted) return;
      _showSnackBar('Error saving profile: $e');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
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
            const Text(
              'Regie Data',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            )
          ],
        ),
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.waving_hand,
                            color: _green,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Welcome ${widget.displayName ?? 'there'}! PLease complete your profile to continue',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Personal information
                  _sectionCard(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    children: [
                      _field('First Name', _firstnameController, 'John',
                          isRequired: true),
                      _field('Surname', _surnameController, 'Doe',
                          isRequired: true),
                      _field('Other Name(s)', _othernameController, 'Optional'),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Gender and DOB
                  Row(
                    children: [
                      Expanded(child: _genderDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _dobPicker()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Information
                  _sectionCard(
                      icon: Icons.phone_outlined,
                      title: 'Contact Information',
                      children: [
                        _phoneField(),
                        _field('Residence', _residenceController,
                            'e.g. Abeka-Lapaz'),
                      ]),
                  const SizedBox(height: 16),

                  // Work & Education
                  _sectionCard(
                    icon: Icons.work_outline,
                    title: 'Work & Education',
                    children: [
                      _field(
                          'Occupation', _occupationController, 'e.g. Student'),
                      _checkboxGroup(),
                      if (_isWorking) ...[
                        const SizedBox(height: 12),
                        _field('Place of Work', _placeofworkController,
                            'e.g. Ghana Ltd',
                            isRequired: true),
                      ],
                      if (_isSchooling) ...[
                        _field('Place of School', _placeofschoolController,
                            'e.g. KNUST',
                            isRequired: true),
                        _field('Course of Study', _courseofstudyController,
                            'e.g. Computer Science'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Organization Information
                  _sectionCard(
                    icon: Icons.business_outlined,
                    title: 'Organization Information',
                    children: [
                      const SizedBox(height: 14),
                      _field('Family', _familyController, 'e.g. Truth'),
                      _field('Department', _departmentController, 'e.g. Media'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Complete Profile Button
                  GestureDetector(
                    onTap: _isLoading ? null : _completeProfile,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [_green, _greenDark]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Complete Profile',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: const Center(
                child: CircularProgressIndicator(
                  color: _green,
                  strokeWidth: 2.5,
                ),
              ),
            ),
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
          ),
      ],
    );
  }

  Widget _inputBase(
      {required TextEditingController controller,
      required String hint,
      bool obscure = false,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? formatters,
      String? helper,
      Widget? suffix}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _green,
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
        helperStyle:
            TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
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
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: isRequired),
        const SizedBox(height: 6),
        _inputBase(
            controller: controller, hint: hint, keyboardType: keyboardType),
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
        _inputBase(
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
                Expanded(
                  child: Text(
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
            _isWorking,
            (v) => setState(() => _isWorking = v ?? false),
          ),
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          _styledCheckbox(
            'I am currently schooling',
            _isSchooling,
            (v) => setState(() => _isSchooling = v ?? false),
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

  @override
  void dispose() {
    _firstnameController.dispose();
    _surnameController.dispose();
    _othernameController.dispose();
    _phonenumberController.dispose();
    _residenceController.dispose();
    _occupationController.dispose();
    _placeofschoolController.dispose();
    _placeofworkController.dispose();
    _courseofstudyController.dispose();
    _familyController.dispose();
    _departmentController.dispose();
    super.dispose();
  }
}
