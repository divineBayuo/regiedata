import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';

class GoogleProfileCompletionScreen extends StatefulWidget {
  final User user;
  final String email;
  final String? displayName;

  const GoogleProfileCompletionScreen(
      {super.key, required this.user, required this.email, this.displayName});

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

  Future<void> _selectedDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              onSurface: Colors.black,
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
        'role': _selectedRole == 'admin' ? 'pending_admin' : 'user',
        'isApproved': _selectedRole == 'user',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      if (_selectedRole == 'admin') {
        _showSnackBar('Profile completed! Admin request submitted.');
      } else {
        _showSnackBar('Profile completed successfully!');
      }

      // Navigate based on role
      navigateBasedOnRole(context);
    } catch (e) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.green,
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Text(
                          'Welcome ${widget.displayName ?? 'User'}! PLease complete your profile to continue',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // Account Type
                _buildSectionHeader('Account Type'),
                const SizedBox(
                  height: 12,
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('User'),
                        subtitle:
                            const Text('Mark attendance and view records'),
                        value: 'user',
                        groupValue: _selectedRole,
                        activeColor: Colors.green,
                        onChanged: (value) => setState(
                          () => _selectedRole = value!,
                        ),
                      ),
                      RadioListTile<String>(
                        title: const Text('Admin'),
                        subtitle: const Text(
                            'Create codes, analyze data (requires approval)'),
                        value: 'admin',
                        groupValue: _selectedRole,
                        activeColor: Colors.green,
                        onChanged: (value) => setState(
                          () => _selectedRole = value!,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),

                // Personal information
                _buildSectionHeader('Personal Information'),
                const SizedBox(
                  height: 16,
                ),

                _buildTextField('First Name', _firstnameController, 'John',
                    isRequired: true),
                _buildTextField('Surname', _surnameController, 'Doe',
                    isRequired: true),
                _buildTextField(
                    'Other Name(s)', _othernameController, 'Optional'),

                const SizedBox(
                  height: 16,
                ),

                // Gender and DOB
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Gender',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              )
                            ],
                            onChanged: (value) => setState(
                              () => _selectedGender = value,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Date of Birth',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          InkWell(
                            onTap: () => _selectedDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedDateOfBirth == null
                                          ? 'Select'
                                          : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                                      style: TextStyle(
                                        color: _selectedDateOfBirth == null
                                            ? Colors.grey.shade600
                                            : Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),

                // Contact Information
                _buildSectionHeader('Contact Information'),
                const SizedBox(
                  height: 16,
                ),

                _buildPhoneField(),
                _buildTextField(
                    'Residence', _residenceController, 'e.g. Abeka-Lapaz'),

                const SizedBox(
                  height: 24,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),

                // Work & Education
                _buildSectionHeader('Work & Education'),
                const SizedBox(
                  height: 16,
                ),

                _buildTextField(
                    'Occupation', _occupationController, 'e.g. Student'),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('I am currently working'),
                        value: _isWorking,
                        activeColor: Colors.green,
                        onChanged: (value) =>
                            setState(() => _isWorking = value ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('I am currently schooling'),
                        value: _isSchooling,
                        activeColor: Colors.green,
                        onChanged: (value) =>
                            setState(() => _isSchooling = value ?? false),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                if (_isWorking)
                  _buildTextField(
                      'Place of Work', _placeofworkController, 'e.g. Ghana Ltd',
                      isRequired: true),

                if (_isSchooling) ...[
                  _buildTextField(
                      'Place of School', _placeofschoolController, 'e.g. KNUST',
                      isRequired: true),
                  _buildTextField('Course of Study', _courseofstudyController,
                      'e.g. Computer Science'),
                ],

                const SizedBox(
                  height: 24,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),

                // Church Information
                _buildSectionHeader('Church Information'),
                const SizedBox(
                  height: 16,
                ),

                _buildTextField('Family', _familyController, 'e.g. Truth'),
                _buildTextField(
                    'Department', _departmentController, 'e.g. Media'),

                const SizedBox(
                  height: 32,
                ),

                // Complete Profile Button
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Complete Profile',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 40,
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                  strokeWidth: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint,
      {bool isRequired = false}) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade400,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.green,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 16,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                ),
              )
            ],
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        TextFormField(
          controller: _phonenumberController,
          decoration: InputDecoration(
            hintText: '0244123456',
            helperText: 'Enter 10 digits only',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2),
            ),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 16,),
      ],
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
