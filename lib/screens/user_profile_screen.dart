import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name and surname are required')));
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
        'placeOfWork': _isWorking && _placeOfWorkController.text.trim().isEmpty
            ? _placeOfWorkController.text.trim()
            : null,
        'placeOfSchool':
            _isSchooling && _placeOfSchoolController.text.trim().isEmpty
                ? _placeOfSchoolController.text.trim()
                : null,
        'courseOfStudy': _isSchooling && _courseController.text.trim().isEmpty
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile 🙎🏻‍♂️',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
            )
          else
            IconButton(
              onPressed: () {
                setState(() => _isEditing = false);
                if (_userData != null) _initControllers(_userData!);
              },
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _isEditing ? _buildEditForm() : _buildViewProfile(),
                if (_isSaving)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    ),
                  )
              ],
            ),
    );
  }

  /// View Profile Mode
  Widget _buildViewProfile() {
    if (_userData == null) {
      return const Center(child: Text('No Data Found'));
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.lightGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: Text(
                    initials,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'User',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        data['email'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionCard('Personal Information', [
            _infoRow(
                'Other Name', data['othername'] ?? data['otherName'] ?? '-'),
            _infoRow('Gender', data['gender']),
            _infoRow('Date of Birth', _formatDob(data['dateOfBirth'])),
          ]),

          const SizedBox(height: 14),

          _sectionCard('Contact Information', [
            _infoRow(
                'Phone Number', data['phoneNumber'] ?? data['phone_number']),
            _infoRow('Residence', data['residence']),
          ]),

          const SizedBox(height: 14),

          _sectionCard('Work & Education', [
            _infoRow('Occupation', data['occupation']),
            if (data['isWorking'] == true)
              _infoRow('Place of Work', data['placeOfWork']),
            if (data['isSchooling'] == true) ...[
              _infoRow('Place of School', data['placeOfSchool']),
              _infoRow('Course of Study', data['courseOfStudy']),
            ],
          ]),

          const SizedBox(height: 14),

          _sectionCard('Organization Information', [
            _infoRow('Family', data['family']),
            _infoRow('Department', data['department']),
          ]),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    // Filter empty rows
    final nonEmpty =
        children.where((w) => w is! SizedBox || w.key != null).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          const Divider(),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 13),
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
          _sectionHeader('Personal Information'),
          _editField(_firstnameController, 'First Name *'),
          _editField(_surnameController, 'Surname *'),
          _editField(_othernameController, 'Other Name'),
          const Divider(height: 32),
          _sectionHeader('Contact Information'),
          _editField(_phoneNumberController, 'Phone Number',
              type: TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ]),
          _editField(_residenceController, 'Residence'),
          const Divider(height: 32),
          _sectionHeader('Work & Education'),
          _editField(_occupationController, 'Occupation'),
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('Currently Working'),
                  value: _isWorking,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => _isWorking = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Currently Schooling'),
                  value: _isSchooling,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => _isSchooling = v ?? false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isWorking) _editField(_placeOfWorkController, 'Place of Work'),
          if (_isSchooling) ...[
            _editField(_placeOfSchoolController, 'Place of School'),
            _editField(_courseController, 'Course of Study'),
          ],
          const Divider(height: 32),
          _sectionHeader('Organization Information'),
          _editField(_familyController, 'Family'),
          _editField(_departmentController, 'Department'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  )),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _editField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text,
      List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: type,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}
