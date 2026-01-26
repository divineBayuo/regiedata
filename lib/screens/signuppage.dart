import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/screens/google_profile_completion_screen.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';
import 'package:regie_data/screens/signinpage.dart';

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

  // Church information
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
  String _selectedRole = 'user'; // user or admin

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
      clientId:
          '674155089068-bmhg625i9o99aq2caduqbudp6ugbabdg.apps.googleusercontent.com');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // email validation regex
  final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  // password validation regex
  final RegExp _passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

  Future<void> _selectDate(BuildContext context) async {
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
                    onSurface: Colors.black)),
            child: child!);
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  bool _validateEmail(String email) {
    return _emailRegex.hasMatch(email);
  }

  bool _validatePassword(String password) {
    return _passwordRegex.hasMatch(password);
  }

  bool _validatePhoneNumber(String phone) {
    // Remove spaces and dashes
    String cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    // check if exactly 10 digits
    return cleanPhone.length == 10 && RegExp(r'^\d{10}$').hasMatch(cleanPhone);
  }

  Future<void> _signUpWithEmail() async {
    // Validation
    if (_firstnameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty) {
      _showSnackBar('PLease enter your first Name and surname.');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email address.');
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
      _showSnackBar('Phone number must be exactly 10 digits.');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email address.');
      return;
    }

    if (!_validateEmail(_emailController.text.trim())) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    if (!_validatePassword(_passwordController.text)) {
      _showSnackBar('Password must be at least 8 characters and include:\n'
          '- Uppercase letter (A-Z)\n'
          '- Lowercase letter (a-z)\n'
          '- Number (0-9\n'
          '- Special character (@\$!%*?&)');
      return;
    }

    if (_passwordController.text != _confirmpasswordController.text) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    if (isWorking && _placeofworkController.text.trim().isEmpty) {
      _showSnackBar('Please enter your place of work.');
      return;
    }

    if (isSchooling && _placeofschoolController.text.trim().isEmpty) {
      _showSnackBar('Please enter your place of school.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      // Set display name
      String displayName =
          '${_firstnameController.text.trim()} ${_surnameController.text.trim()}';
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();

      // Save to firestore
      await _saveUserToFirestore(userCredential.user!.uid);

      // Navigate to organizationn selector
      if (!mounted) return;
      final bool? orgSelected = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OrganizationSelectorScreen(),
        ),
      );

      // If no organization selected, delete auth account
      if (orgSelected != true) {
        await _firestore.collection('users').doc(userCredential.user!.uid).delete();
        await userCredential.user?.delete();
        if (!mounted) return;
        _showSnackBar('You must join or create an organization');
        setState(() => _isLoading = false);
        return;
      }

      // Now save user to firestore
      await _saveUserToFirestore(userCredential.user!.uid);

      if (!mounted) return;
      if (_selectedRole == 'admin') {
        _showSnackBar('Admin request submitted! Awaiting approval.');
      } else {
        _showSnackBar('Account created successfully!');
      }

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
    String cleanPhone =
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

      /* // Check if user already has organization membership
      QuerySnapshot membershipCheck = await _firestore
          .collection('organization_members')
          .where('userId', isEqualTo: userCredential.user!.uid)
          .limit(1)
          .get();

      bool needSetup = membershipCheck.docs.isEmpty || !userDoc.exists;

      if (needSetup) {
        if (membershipCheck.docs.isEmpty) {
          final bool? orgSelected = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrganizationSelectorScreen(),
            ),
          );

          if (orgSelected != true) {
            await userCredential.user?.delete();
            await _googleSignIn.signOut();
            if (!mounted) return;
            _showSnackBar('You must create or join an organization');
            setState(() => _isLoading = false);
            return;
          }
        }

        if (!mounted) return;
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
        navigateBasedOnRole(context);
      } */
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Google sign-up failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _firstnameController.dispose();
    _othernameController.dispose();
    _familyController.dispose();
    _departmentController.dispose();
    _phonenumberController.dispose();
    _residenceController.dispose();
    _occupationController.dispose();
    _placeofworkController.dispose();
    _placeofschoolController.dispose();
    _courseofstudyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmpasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      'Join the Regie community',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(
                      height: 30,
                    ),

                    // Role selection
                    _buildSectionHeader('Account Type'),
                    const SizedBox(
                      height: 16,
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('User'),
                            subtitle: const Text(
                                'Mark attendance, view my attendance records.'),
                            value: 'user',
                            groupValue: _selectedRole,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Admin'),
                            subtitle: const Text(
                                'Create attendance codes, analyze all data. (Requires approval)'),
                            value: 'admin',
                            groupValue: _selectedRole,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 20,
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
                    _buildTextField('Other Name(s)', _othernameController,
                        'Kofi (Optional)'),
                    const SizedBox(
                      height: 20,
                    ),

                    // Gender and Date of Birth
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
                                      fontWeight: FontWeight.w600),
                                ),
                                const Text(
                                  ' *',
                                  style: TextStyle(color: Colors.red),
                                )
                              ],
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 20),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade400,
                                            width: 1.5)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.green, width: 2),
                                    )),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(
                                      value: 'Female', child: Text('Female'))
                                ],
                                onChanged: ((value) {
                                  setState(() => _selectedGender = value);
                                }))
                          ],
                        )),
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
                                      fontWeight: FontWeight.w600),
                                ),
                                const Text(
                                  ' *',
                                  style: TextStyle(color: Colors.red),
                                )
                              ],
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.grey.shade400, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedDateOfBirth == null
                                          ? 'Select'
                                          : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                                      style: TextStyle(
                                          color: _selectedDateOfBirth == null
                                              ? Colors.grey.shade600
                                              : Colors.black),
                                      overflow: TextOverflow.ellipsis,
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
                        ))
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 20,
                    ),

                    // Contact Information
                    _buildSectionHeader('Contact Information'),
                    const SizedBox(
                      height: 16,
                    ),

                    _buildPhoneField(),
                    _buildTextField('Residence', _residenceController,
                        'Abeka-Lapaz (Optional)'),

                    const SizedBox(
                      height: 20,
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 20,
                    ),

                    // Work/School Info
                    _buildSectionHeader('Work & Education'),
                    const SizedBox(
                      height: 16,
                    ),

                    _buildTextField('Occupation', _occupationController,
                        'Software Engineer/Student (Optional)'),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: const Text('I am currently working'),
                            value: isWorking,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() => isWorking = value ?? false);
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('I am currently schooling'),
                            value: isSchooling,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() => isSchooling = value ?? false);
                            },
                          )
                        ],
                      ),
                    ),

                    if (isWorking)
                      _buildTextField(
                          'Place of Work', _placeofworkController, 'Ghana Ltd',
                          isRequired: true),

                    if (isSchooling) ...[
                      _buildTextField(
                          'Place of School', _placeofschoolController, 'KNUST',
                          isRequired: true),
                      _buildTextField(
                        'Course of Study',
                        _courseofstudyController,
                        'Computer Science (Optional)',
                      )
                    ],

                    const SizedBox(
                      height: 20,
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 20,
                    ),

                    // Church Info
                    _buildSectionHeader('Church Information'),
                    const SizedBox(
                      height: 16,
                    ),

                    _buildTextField(
                        'Family', _familyController, 'Truth (Optional)'),
                    _buildTextField('Department', _departmentController,
                        'Media (Optional)'),

                    const SizedBox(
                      height: 20,
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 20,
                    ),

                    // Authentication
                    _buildSectionHeader('Account Credentials'),
                    const SizedBox(
                      height: 16,
                    ),

                    _buildTextField('Email Address', _emailController,
                        'your.email@example.com',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true),
                    _buildPasswordField(
                        'Password',
                        _passwordController,
                        _obscurePassword,
                        () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        'Minimum 8 characters, uppercase, lowercase, number & special char',
                        isRequired: true),
                    _buildPasswordField(
                        'Confirm Password',
                        _confirmpasswordController,
                        _obscureConfirmPassword,
                        () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                        'Re-enter Password',
                        isRequired: true),

                    const SizedBox(
                      height: 30,
                    ),

                    // Create-account button
                    Container(
                      width: double.infinity,
                      height: 65,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                              colors: [Colors.green, Colors.lightGreen],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight)),
                      child: TextButton(
                          onPressed: _isLoading ? null : _signUpWithEmail,
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white),
                          )),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // or sign up with
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(
                          thickness: 1,
                        )),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'or sign up with',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Expanded(
                            child: Divider(
                          thickness: 1,
                        )),
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // Google sign-up
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 65,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 6,
                                spreadRadius: 2,
                                offset: const Offset(0, 2))
                          ]),
                      child: TextButton(
                          onPressed: _isLoading ? null : _signUpWithGoogle,
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.black87,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/icon/google_logo.png',
                                height: 40,
                                width: 40,
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Flexible(
                                  child: Text(
                                'Sign Up with Google',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey.shade700),
                              ))
                            ],
                          )),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // Already have an account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?',
                            style: TextStyle(color: Colors.grey.shade700)),
                        TextButton(
                            onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const Signinpage())),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ))
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
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                  strokeWidth: 4,
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint,
      {TextInputType keyboardType = TextInputType.text,
      bool isRequired = false}) {
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
                    fontWeight: FontWeight.w600),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red),
                )
            ],
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        TextFormField(
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontStyle: FontStyle.italic),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade400, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2))),
          keyboardType: keyboardType,
          controller: controller,
        ),
        const SizedBox(
          height: 20,
        )
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              'Phone Number',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600),
            ),
            const Text(
              ' *',
              style: TextStyle(color: Colors.red),
            )
          ],
        ),
      ),
      const SizedBox(
        height: 6,
      ),
      TextFormField(
        decoration: InputDecoration(
          hintText: '0244123456',
          helperText: 'Enter 10 digits only',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green, width: 2)),
        ),
        keyboardType: TextInputType.phone,
        controller: _phonenumberController,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10)
        ],
      ),
      const SizedBox(
        height: 20,
      ),
    ]);
  }

  Widget _buildPasswordField(String label, TextEditingController controller,
      bool obscureText, VoidCallback onToggle, String hint,
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
                    fontWeight: FontWeight.w600),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red),
                )
            ],
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        TextFormField(
          decoration: InputDecoration(
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.green,
                ),
              ),
              hintText: hint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.grey.shade400, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2))),
          obscureText: obscureText,
          controller: controller,
        ),
        const SizedBox(
          height: 20,
        ),
      ],
    );
  }
}
