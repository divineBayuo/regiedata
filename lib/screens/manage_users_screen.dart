import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/services/organization_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrganizationService _orgService = OrganizationService();

  late TabController _tabController;

  // Filter states
  String _selectedGender = 'All';
  String _selectedDepartment = 'All';
  String _selectedFamily = 'All';

  // Analytics data
  Map<String, int> _genderStats = {};
  Map<String, int> _departmentStats = {};
  Map<String, int> _familyStats = {};
  Map<String, int> _ageGroupStats = {};
  Map<String, int> _occupationStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();

    // Get all members
    final membersSnapshot = await _firestore
        .collection('organization_members')
        .where('organizationId', isEqualTo: orgId)
        .get();

    Map<String, int> genderStats = {};
    Map<String, int> departmentStats = {};
    Map<String, int> familyStats = {};
    Map<String, int> ageGroupStats = {};
    Map<String, int> occupationStats = {};

    for (var memberDoc in membersSnapshot.docs) {
      final userId = memberDoc['userId'];
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) continue;

      final userData = userDoc.data()!;

      // Gender stats
      final gender = userData['gender'] ?? 'Not specified';
      genderStats[gender] = (genderStats[gender] ?? 0) + 1;

      // Department stats
      final department = userData['department'] ?? 'Not assigned';
      departmentStats[department] = (departmentStats[department] ?? 0) + 1;

      // Family stats
      final family = userData['family'] ?? 'Not assigned';
      familyStats[family] = (familyStats[family] ?? 0) + 1;

      // Age group stats
      final dob = userData['dateOfBirth'];
      if (dob != null && dob.isNotEmpty) {
        try {
          final birthDate = DateTime.parse(dob);
          final age = DateTime.now().difference(birthDate).inDays ~/ 365;
          String ageGroup;

          if (age < 18) {
            ageGroup = 'Under 18';
          } else if (age < 30) {
            ageGroup = '18-29';
          } else if (age < 50) {
            ageGroup = '30-49';
          } else {
            ageGroup = '50+';
          }

          ageGroupStats[ageGroup] = (ageGroupStats[ageGroup] ?? 0) + 1;
        } catch (e) {
          // invalid date format
          debugPrint('Invalid date format for user: $dob');
        }
      }

      // Occupation stats
      final isWorking = userData['isWorking'] ?? false;
      final isSchooling = userData['isSchooling'] ?? false;

      String occupation;
      if (isWorking && isSchooling) {
        occupation = 'Working & Studying';
      } else if (isWorking) {
        occupation = 'Working';
      } else if (isSchooling) {
        occupation = 'Student';
      } else {
        occupation = 'Other';
      }
      occupationStats[occupation] = (occupationStats[occupation] ?? 0) + 1;
    }

    setState(() {
      _genderStats = genderStats;
      _departmentStats = departmentStats;
      _familyStats = familyStats;
      _ageGroupStats = ageGroupStats;
      _occupationStats = occupationStats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Manage Members'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Members'),
            Tab(text: 'Pending Admins'),
            Tab(text: 'Admins'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllMembersTab(),
          _buildPendingAdminsTab(),
          _buildAdminsTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddMemberDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildAllMembersTab() {
    // Get organization members first, then fetch user details
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Genders', _selectedGender == 'All', () {
                  setState(() => _selectedGender = 'All');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Male', _selectedGender == 'Male', () {
                  setState(() => _selectedGender = 'Male');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Female', _selectedGender == 'Female', () {
                  setState(() => _selectedGender = 'Female');
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                    'All Departments', _selectedDepartment == 'All', () {
                  setState(() => _selectedDepartment = 'All');
                }),
                ..._departmentStats.keys.map((dept) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildFilterChip(dept, _selectedDepartment == dept,
                          () {
                        setState(() => _selectedDepartment = dept);
                      }),
                    )),
                const SizedBox(width: 8),
                _buildFilterChip('All Families', _selectedFamily == 'All', () {
                  setState(() => _selectedFamily = 'All');
                }),
                ..._familyStats.keys.map((family) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildFilterChip(family, _selectedFamily == family,
                          () {
                        setState(() => _selectedFamily = family);
                      }),
                    )),
              ],
            ),
          ),
        ),
        Expanded(child: _buildMembersList('all')),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingAdminsTab() {
    return _buildMembersList('pending_admins');
  }

  Widget _buildAdminsTab() {
    return _buildMembersList('admins');
  }

  Widget _buildMembersList(String filter) {
    return FutureBuilder<String?>(
      future: OrganizationContext.getCurrentOrganizationId(),
      builder: (context, orgSnapshot) {
        if (!orgSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orgId = orgSnapshot.data!;

        return StreamBuilder<QuerySnapshot>(
          stream: _getMemberStream(orgId, filter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      filter == 'pending_admins'
                          ? 'No Pending Admin Requests'
                          : filter == 'admins'
                              ? 'No Admins'
                              : 'No Members',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    )
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final memberDoc = snapshot.data!.docs[index];
                final memberData = memberDoc.data() as Map<String, dynamic>;
                final userId = memberData['userId'];

                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(userId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;

                    // Apply filters
                    if (filter == 'all') {
                      if (_selectedGender != 'All' &&
                          userData['gender'] != _selectedGender) {
                        return const SizedBox.shrink();
                      }
                      if (_selectedDepartment != 'All' &&
                          userData['department'] != _selectedDepartment) {
                        return const SizedBox.shrink();
                      }
                      if (_selectedFamily != 'All' &&
                          userData['family'] != _selectedFamily) {
                        return const SizedBox.shrink();
                      }
                    }

                    return _buildMemberCard(
                      memberDoc.id,
                      userData,
                      memberData,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getMemberStream(String orgId, String filter) {
    var query = _firestore
        .collection('organization_members')
        .where('organizationId', isEqualTo: orgId);

    if (filter == 'pending_admins') {
      query = query
          .where('role', isEqualTo: 'admin')
          .where('isApproved', isEqualTo: false);
    } else if (filter == 'admins') {
      query = query
          .where('role', isEqualTo: 'admin')
          .where('isApproved', isEqualTo: true);
    }
    return query.snapshots();
  }

  Widget _buildMemberCard(
    String membershipId,
    Map<String, dynamic> userData,
    Map<String, dynamic> memberData,
  ) {
    final name =
        '${userData['firstname'] ?? ''} ${userData['surname'] ?? ''}'.trim();
    final email = userData['email'] ?? 'No email';
    final role = memberData['role'] ?? 'user';
    final isApproved = memberData['isApproved'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: role == 'admin' && isApproved
              ? Colors.green
              : role == 'admin'
                  ? Colors.orange
                  : Colors.blue,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(name.isNotEmpty ? name : 'Unnamed User'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            if (userData['department'] != null)
              Text(
                '${userData['department']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(height: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(height: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'promote',
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 20,
                    color: Colors.green,
                  ),
                  SizedBox(height: 8),
                  Text('Promote to Admin'),
                ],
              ),
            ),
            if (role == 'admin' && !isApproved)
              const PopupMenuItem(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check, size: 20, color: Colors.green),
                    SizedBox(height: 8),
                    Text('Approve Admin'),
                  ],
                ),
              ),
            if (role == 'admin' && !isApproved)
              const PopupMenuItem(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.close, size: 20, color: Colors.red),
                    SizedBox(height: 8),
                    Text('Reject'),
                  ],
                ),
              ),
            if (role == 'admin' && isApproved)
              const PopupMenuItem(
                value: 'revoke',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle, size: 20, color: Colors.orange),
                    SizedBox(height: 8),
                    Text('Revoke Admin'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Remove from Org'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'view':
                _showMemberDetails(userData);
                break;
              case 'edit':
                _showEditMemberDialog(membershipId, userData);
                break;
              case 'promote':
                _promoteToAdmin(membershipId);
                break;
              case 'approve':
                _approveAdmin(membershipId);
                break;
              case 'reject':
                _rejectAdmin(membershipId);
                break;
              case 'revoke':
                _revokeAdmin(membershipId);
                break;
              case 'delete':
                _removeMember(membershipId);
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Member Demographics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),

          // Gender Distribution
          _buildAnalyticsSection(
            'Gender Distribution',
            _genderStats,
            [
              Colors.blue,
              Colors.pink,
              Colors.grey,
            ],
          ),

          const SizedBox(height: 24),

          // Department Distribution
          _buildAnalyticsSection(
            'Department Distribution',
            _departmentStats,
            [
              Colors.purple,
              Colors.orange,
              Colors.teal,
              Colors.indigo,
              Colors.red
            ],
          ),

          const SizedBox(height: 24),

          // Family Distribution
          _buildAnalyticsSection(
            'Family Distribution',
            _familyStats,
            [
              Colors.green,
              Colors.blue,
              Colors.orange,
              Colors.purple,
              Colors.teal
            ],
          ),

          const SizedBox(height: 24),

          // Age Groups
          _buildAnalyticsSection(
            'Age Groups',
            _ageGroupStats,
            [
              Colors.lightBlue,
              Colors.blue,
              Colors.indigo,
              Colors.deepPurple,
            ],
          ),

          const SizedBox(height: 24),

          // Occupation Status
          _buildAnalyticsSection(
            'Occupation Status',
            _occupationStats,
            [
              Colors.green,
              Colors.orange,
              Colors.blue,
              Colors.grey,
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(
    String title,
    Map<String, int> data,
    List<Color> colors,
  ) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            'No data for $title',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final total = data.values.reduce((a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Pie chart
          Center(
            child: SizedBox(
              height: 200,
              width: 200,
              child: CustomPaint(
                painter: PieChartPainter(data, colors),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Legend
          ...data.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final dataEntry = entry.value;
            final percentage =
                (dataEntry.value / total * 100).toStringAsFixed(1);
            final color = colors[index % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dataEntry.key,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '$percentage% (${dataEntry.value})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          })
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final formKey = GlobalKey<FormState>();
    final firstnameController = TextEditingController();
    final surnameController = TextEditingController();
    final othernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedGender = 'Male';
    String selectedDepartment = 'Not assigned';
    String selectedFamily = 'Not assigned';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Member'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstnameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: surnameController,
                    decoration: const InputDecoration(
                      labelText: 'Surname *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: othernameController,
                    decoration: const InputDecoration(
                      labelText: 'Other Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) return 'Required';
                      if (!value!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Male', 'Female', 'Other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (value) => selectedGender = value!,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Not assigned', ..._departmentStats.keys]
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (value) => selectedDepartment = value!,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFamily,
                    decoration: const InputDecoration(
                      labelText: 'Family',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Not assigned', ..._familyStats.keys]
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) => selectedFamily = value!,
                  )
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final orgId =
                    await OrganizationContext.getCurrentOrganizationId();
                if (orgId == null) throw 'No organizationn selected';

                // Create a temporary user document (without Firebase Auth)
                // Proper signup needed after
                final userDoc = await _firestore.collection('users').add({
                  'firstname': firstnameController.text.trim(),
                  'surname': surnameController.text.trim(),
                  'othername': othernameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                  'gender': selectedGender,
                  'department': selectedDepartment,
                  'family': selectedFamily,
                  'createdAt': FieldValue.serverTimestamp(),
                  'role': 'user',
                  'isApproved': true,
                  'addedManually': true, // Flag for manually added users
                });

                // Add to organization
                await _orgService.addMemberToOrganization(
                  userId: userDoc.id,
                  organizationId: orgId,
                  role: 'user',
                  isApproved: true,
                );

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Member added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );

                _loadAnalytics(); // Refresh analytics
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Member'),
          )
        ],
      ),
    );
  }

  void _showMemberDetails(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            '${userData['firstname'] ?? ''} ${userData['surname'] ?? ''}'
                .trim()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', userData['email'] ?? 'N/A'),
              _buildDetailRow('Phone', userData['phoneNumber'] ?? 'N/A'),
              _buildDetailRow('Gender', userData['gender'] ?? 'N/A'),
              _buildDetailRow(
                  'Date of Birth', userData['dateOfBirth'] ?? 'N/A'),
              _buildDetailRow('Residence', userData['residence'] ?? 'N/A'),
              _buildDetailRow('Department', userData['department'] ?? 'N/A'),
              _buildDetailRow('Family', userData['family'] ?? 'N/A'),
              _buildDetailRow('Occupation', userData['occupation'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value))
        ],
      ),
    );
  }

  void _showEditMemberDialog(String userId, Map<String, dynamic> userData) {
    final firstname = userData['firstname'] ?? userData['firstName'] ?? '';
    final surname = userData['surname'] ?? '';
    final fullname = '$firstname $surname'.trim();

    final firstnameController = TextEditingController(text: firstname);
    final surnameController = TextEditingController(text: surname);
    final phonenumberController = TextEditingController(
        text: userData['phoneNumber'] ?? userData['phone_number'] ?? '');
    final residenceController =
        TextEditingController(text: userData['residence'] ?? '');
    final occupationController =
        TextEditingController(text: userData['occupation'] ?? '');
    final familyController =
        TextEditingController(text: userData['family'] ?? '');
    final departmentController =
        TextEditingController(text: userData['department'] ?? '');
    final placeofworkController =
        TextEditingController(text: userData['placeOfWork'] ?? '');
    final placeofschoolController =
        TextEditingController(text: userData['placeOfSchool'] ?? '');
    final courseofstudyController =
        TextEditingController(text: userData['courseOfStudy'] ?? '');

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit: $fullname'),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editField(firstnameController, 'First Name'),
                  _editField(surnameController, 'Surname'),
                  _editField(phonenumberController, 'Phone Number',
                      type: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10)
                      ]),
                  _editField(residenceController, 'Residence'),
                  _editField(occupationController, 'Occupation'),
                  _editField(familyController, 'Family'),
                  _editField(departmentController, 'Department'),
                  _editField(placeofworkController, 'Place of Work'),
                  _editField(placeofschoolController, 'Place of School'),
                  _editField(courseofstudyController, 'Course of Study'),
                  if (isSaving) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .update({
                          'firstname': firstnameController.text.trim(),
                          'surname': surnameController.text.trim(),
                          'residence': residenceController.text.trim().isEmpty
                              ? null
                              : residenceController.text.trim(),
                          'occupation': occupationController.text.trim().isEmpty
                              ? null
                              : occupationController.text.trim(),
                          'family': familyController.text.trim().isEmpty
                              ? null
                              : familyController.text.trim(),
                          'department': departmentController.text.trim().isEmpty
                              ? null
                              : departmentController.text.trim(),
                          'placeOfWork':
                              placeofworkController.text.trim().isEmpty
                                  ? null
                                  : placeofworkController.text.trim(),
                          'placeOfSchool':
                              placeofschoolController.text.trim().isEmpty
                                  ? null
                                  : placeofschoolController.text.trim(),
                          'courseOfStudy':
                              courseofstudyController.text.trim().isEmpty
                                  ? null
                                  : courseofstudyController.text.trim(),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Member details updated'),
                          backgroundColor: Colors.green,
                        ));
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _promoteToAdmin(String membershipId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote Admin'),
        content: const Text(
            'Promote this user to admin? (They will need approval.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _firestore
        .collection('organization_members')
        .doc(membershipId)
        .update({
      'role': 'admin',
      'isApproved': false,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User promoted (pending approval)'),
        ),
      );
    }
  }

  Future<void> _approveAdmin(String membershipId) async {
    await _orgService.approveAdmin(membershipId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectAdmin(String membershipId) async {
    await _firestore
        .collection('organization_members')
        .doc(membershipId)
        .update({'role': 'user', 'isApproved': false});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _revokeAdmin(String membershipId) async {
    await _orgService.revokeAdmin(membershipId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin privileges revoked'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _removeMember(String membershipId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text(
            'Are you sure you want to remove this member from this organization?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore
          .collection('organization_members')
          .doc(membershipId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// Custom pie chart painter
class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.reduce((a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const pi = 3.14159;

    double startAngle = -90 * (pi / 180); // from the top

    data.entries.toList().asMap().forEach((index, entry) {
      final sweepAngle = (entry.value / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
