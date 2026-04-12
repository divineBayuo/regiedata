import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regie_data/models/plan_limits.dart';
import 'package:regie_data/screens/subscription_screen.dart';
import 'package:regie_data/services/subscription_service.dart';

// theme colors
const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers for editable fields

  late TextEditingController _firstnameController;
  late TextEditingController _surnameController;
  late TextEditingController _othernameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _residenceController;
  late TextEditingController _occupationController;
  late TextEditingController _familyController;
  late TextEditingController _departmentController;
  late TextEditingController _placeOfWorkController;
  late TextEditingController _placeOfSchoolController;
  late TextEditingController _courseController;
  bool _isWorking = false;
  bool _isSchooling = false;

  String _currentPlan = 'free';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPlan();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userData = data;
          _isLoading = false;
        });
        _initControllers(data);
      }
    } catch (e) {
      debugPrint('Error loading profile" $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error loading profile: $e');
      }
    }
  }

  void _initControllers(Map<String, dynamic> data) {
    _firstnameController = TextEditingController(
        text: data['firstname'] ?? data['firstName'] ?? '');
    _surnameController = TextEditingController(text: data['surname'] ?? '');
    _othernameController = TextEditingController(
        text: data['othername'] ?? data['otherName'] ?? '');
    _phoneNumberController = TextEditingController(
        text: data['phoneNumber'] ?? data['phone_number'] ?? '');
    _residenceController = TextEditingController(text: data['residence'] ?? '');
    _occupationController =
        TextEditingController(text: data['occupation'] ?? '');
    _familyController = TextEditingController(text: data['family'] ?? '');
    _departmentController =
        TextEditingController(text: data['department'] ?? '');
    _placeOfWorkController =
        TextEditingController(text: data['placeOfWork'] ?? '');
    _placeOfSchoolController =
        TextEditingController(text: data['placeOfSchool'] ?? '');
    _courseController =
        TextEditingController(text: data['courseOfStudy'] ?? '');
    _isWorking = data['isWorking'] ?? false;
    _isSchooling = data['isSchooling'] ?? false;
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _surnameController.dispose();
    _othernameController.dispose();
    _phoneNumberController.dispose();
    _residenceController.dispose();
    _occupationController.dispose();
    _familyController.dispose();
    _departmentController.dispose();
    _placeOfWorkController.dispose();
    _placeOfSchoolController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_firstnameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty) {
      _snack('First name and surname are required', error: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'firstname': _firstnameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'othername': _othernameController.text.trim().isEmpty
            ? null
            : _othernameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'residence': _residenceController.text.trim().isEmpty
            ? null
            : _residenceController.text.trim(),
        'occupation': _occupationController.text.trim().isEmpty
            ? null
            : _occupationController.text.trim(),
        'family': _familyController.text.trim().isEmpty
            ? null
            : _familyController.text.trim(),
        'department': _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        'placeOfWork':
            _isWorking && _placeOfWorkController.text.trim().isNotEmpty
                ? _placeOfWorkController.text.trim()
                : null,
        'placeOfSchool':
            _isSchooling && _placeOfSchoolController.text.trim().isNotEmpty
                ? _placeOfSchoolController.text.trim()
                : null,
        'courseOfStudy':
            _isSchooling && _courseController.text.trim().isNotEmpty
                ? _courseController.text.trim()
                : null,
        'isWorking': _isWorking,
        'isSchooling': _isSchooling,
      });

      await _loadProfile();
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      _snack('Profile updated successfully');
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack('Error saving: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : _greenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _loadPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final plan = await SubscriptionService.getUserPlan(uid);
    if (mounted) setState(() => _currentPlan = plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: Text(
          _isEditing ? 'Edit Profile' : 'My Profile',
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _isEditing = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _green.withOpacity(0.25))),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: _green, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      )
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() => _isEditing = false);
                  if (_userData != null) _initControllers(_userData!);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          color: Colors.white.withOpacity(0.5), size: 15),
                      const SizedBox(width: 6),
                      Text('Cancel',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
              color: _green,
              strokeWidth: 2,
            ))
          : Stack(
              children: [
                _isEditing ? _buildEditForm() : _buildViewProfile(),
                if (_isSaving)
                  Container(
                    color: Colors.black.withOpacity(0.45),
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: _green, strokeWidth: 2.5),
                    ),
                  ),
              ],
            ),
    );
  }

  /// View Profile Mode
  Widget _buildViewProfile() {
    if (_userData == null) {
      return Center(
          child: Text(
        'No Data Found',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
      ));
    }
    final data = _userData!;
    final firstname = data['firstname'] ?? data['firstName'] ?? '';
    final surname = data['surname'] ?? '';
    final fullName = '$firstname $surname'.trim();
    final initials = fullName.isNotEmpty
        ? fullName
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase())
            .take(2)
            .join()
        : 'U';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // avatar, name card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2010), Color(0xFF0A1A0C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _green.withOpacity(0.15))),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_green, _greenDark]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: _green.withOpacity(0.3), blurRadius: 16)
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'User',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data['email'] ?? '',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _green.withOpacity(0.2)),
                        ),
                        child: const Text(
                          'Member',
                          style: TextStyle(
                              color: _green,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          _profileSection('Personal Information', [
            _infoRow(
                'Other Name', data['othername'] ?? data['otherName'] ?? '-'),
            _infoRow('Gender', data['gender']),
            _infoRow('Date of Birth', _formatDob(data['dateOfBirth'])),
          ]),

          const SizedBox(height: 16),

          _profileSection('Contact Information', [
            _infoRow(
                'Phone Number', data['phoneNumber'] ?? data['phone_number']),
            _infoRow('Residence', data['residence']),
          ]),

          const SizedBox(height: 12),

          _profileSection('Work & Education', [
            _infoRow('Occupation', data['occupation']),
            if (data['isWorking'] == true)
              _infoRow('Place of Work', data['placeOfWork']),
            if (data['isSchooling'] == true) ...[
              _infoRow('Place of School', data['placeOfSchool']),
              _infoRow('Course of Study', data['courseOfStudy']),
            ],
          ]),

          const SizedBox(height: 12),

          _profileSection('Organization Information', [
            _infoRow('Family', data['family']),
            _infoRow('Department', data['department']),
          ]),

          const SizedBox(height: 12),

          // Subscription card
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ).then((_) => _loadPlan()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _green.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: _green, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Subscription',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                          'Current plan: ${PlanLimits.planName(_currentPlan)}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 12),
                        )
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green.withOpacity(0.2)),
                    ),
                    child: Text(PlanLimits.planName(_currentPlan),
                        style: const TextStyle(
                            color: _green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.2), size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Edit profile buttons
          GestureDetector(
            onTap: () => setState(() => _isEditing = true),
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
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _profileSection(String title, List<Widget> rows) {
    // Filter empty rows
    final nonEmpty = rows.where((w) {
      if (w is SizedBox) return false;
      return true;
    }).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _green,
                    letterSpacing: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 12),
          ...nonEmpty,
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          )
        ],
      ),
    );
  }

  String _formatDob(dynamic value) {
    if (value == null) return '';
    try {
      final dt = DateTime.tryParse(value.toString());
      if (dt == null) return value.toString();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return value.toString();
    }
  }

  /// Edit Form Mode
  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editSection('Personal Information', [
            _editField(_firstnameController, 'First Name *'),
            _editField(_surnameController, 'Surname *'),
            _editField(_othernameController, 'Other Name'),
          ]),
          const SizedBox(height: 14),
          _editSection('Contact Information', [
            _editField(_phoneNumberController, 'Phone Number',
                type: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10)
                ]),
            _editField(_residenceController, 'Residence'),
          ]),
          const Divider(height: 14),
          _editSection('Work & Education', [
            _editField(_occupationController, 'Occupation'),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: Column(
                children: [
                  _styledCheckbox(
                    'Currently Working',
                    _isWorking,
                    (v) => setState(() => _isWorking = v ?? false),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                  ),
                  _styledCheckbox(
                    'Currently Schooling',
                    _isSchooling,
                    (v) => setState(() => _isSchooling = v ?? false),
                  ),
                ],
              ),
            ),
            if (_isWorking) ...[
              const SizedBox(height: 12),
              _editField(_placeOfWorkController, 'Place of Work')
            ],
            if (_isSchooling) ...[
              const SizedBox(height: 12),
              _editField(_placeOfSchoolController, 'Place of School'),
              _editField(_courseController, 'Course of Study'),
            ],
          ]),
          const SizedBox(height: 14),
          _editSection('Organization Information', [
            _editField(_familyController, 'Family'),
            _editField(_departmentController, 'Department'),
          ]),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _isSaving ? null : _saveProfile,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: _isSaving
                    ? null
                    : const LinearGradient(colors: [_green, _greenDark]),
                color: _isSaving ? Colors.white.withOpacity(0.05) : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isSaving
                    ? null
                    : [
                        BoxShadow(
                            color: _green.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4)),
                      ],
              ),
              child: const Center(
                child: Text(
                  'Save Changes',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _editSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 14,
                  decoration: BoxDecoration(
                      color: _green, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _editField(TextEditingController controller, String label,
      {bool isRequired = false,
      TextInputType type = TextInputType.text,
      List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              if (isRequired)
                const Text(' *', style: TextStyle(color: _green, fontSize: 12))
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: type,
            inputFormatters: formatters,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: _green,
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
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
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
        dense: true);
  }
}
