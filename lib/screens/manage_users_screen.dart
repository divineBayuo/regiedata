import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/services/organization_service.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

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
    _tabController.addListener(() => setState(() {}));
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

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(10)),
    ));
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
          'Manage Members',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              Divider(
                height: 1,
                color: Colors.white.withOpacity(0.06),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: _green,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: _green,
                unselectedLabelColor: Colors.white.withOpacity(0.35),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                isScrollable: true,
                tabs: const [
                  Tab(text: 'All Members'),
                  Tab(text: 'Pending Admins'),
                  Tab(text: 'Admins'),
                  Tab(text: 'Analytics'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllMembersTab(),
          _buildMembersList('pending_admins'),
          _buildMembersList('admins'),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? GestureDetector(
              onTap: _showAddMemberDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_green, _greenDark]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _green.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Add Member',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // --- All Members Tab ---
  Widget _buildAllMembersTab() {
    // Get organization members first, then fetch user details
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Genders', _selectedGender == 'All',
                    () => setState(() => _selectedGender = 'All')),
                const SizedBox(width: 8),
                _filterChip('Male', _selectedGender == 'Male',
                    () => setState(() => _selectedGender = 'Male')),
                const SizedBox(width: 8),
                _filterChip('Female', _selectedGender == 'Female',
                    () => setState(() => _selectedGender = 'Female')),
                const SizedBox(width: 8),
                _filterChip('All Depts', _selectedDepartment == 'All',
                    () => setState(() => _selectedDepartment = 'All')),
                ..._departmentStats.keys.map((dept) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _filterChip(dept, _selectedDepartment == dept,
                          () => setState(() => _selectedDepartment = dept)),
                    )),
                const SizedBox(width: 16),
                _filterChip('All Families', _selectedFamily == 'All',
                    () => setState(() => _selectedFamily = 'All')),
                ..._familyStats.keys.map((family) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _filterChip(family, _selectedFamily == family,
                          () => setState(() => _selectedFamily = family)),
                    )),
              ],
            ),
          ),
        ),
        Expanded(child: _buildMembersList('all')),
      ],
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _green.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _green.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _green : Colors.white.withOpacity(0.45),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // --- Member List ---
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
              return const Center(
                  child:
                      CircularProgressIndicator(color: _green, strokeWidth: 2));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Icon(Icons.people_outline,
                          size: 48, color: Colors.white.withOpacity(0.2)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      filter == 'pending_admins'
                          ? 'No Pending Admin Requests'
                          : filter == 'admins'
                              ? 'No Admins'
                              : 'No Members',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    )
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

                    return _memberCard(
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

  Widget _memberCard(
    String membershipId,
    Map<String, dynamic> userData,
    Map<String, dynamic> memberData,
  ) {
    final name =
        '${userData['firstname'] ?? ''} ${userData['surname'] ?? ''}'.trim();
    final email = userData['email'] ?? 'No email';
    final role = memberData['role'] ?? 'user';
    final isApproved = memberData['isApproved'] ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Color avatarColor = const Color(0xFF3B82F6);
    if (role == 'admin' && isApproved) avatarColor = _green;
    if (role == 'admin' && !isApproved) avatarColor = const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: avatarColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(initial,
                  style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : 'Unnamed User',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 12)),
                const SizedBox(height: 4),
                // Role badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: avatarColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    role == 'admin'
                        ? isApproved
                            ? 'Admin'
                            : 'Pending Admin'
                        : 'Member',
                    style: TextStyle(
                        color: avatarColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          // Actions menu
          Theme(
            data: ThemeData.dark(),
            child: PopupMenuButton<String>(
              color: const Color(0xFF1A2A1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: Icon(Icons.more_vert_rounded,
                  color: Colors.white.withOpacity(0.4), size: 20),
              itemBuilder: (_) => [
                _popItem('view', Icons.visibility_outlined, 'View Details',
                    Colors.white),
                _popItem('edit', Icons.edit_outlined, 'Edit',
                    const Color(0xFF3B82F6)),
                _popItem('promote', Icons.admin_panel_settings_outlined,
                    'Promote to Admin', const Color(0xFF2DD4BF)),
                if (role == 'admin' && !isApproved)
                  _popItem('approve', Icons.check_circle_outline,
                      'Approve Admin', _green),
                if (role == 'admin' && !isApproved)
                  _popItem('reject', Icons.cancel_outlined, 'Reject',
                      const Color(0xFFF59E0B)),
                if (role == 'admin' && isApproved)
                  _popItem('revoke', Icons.remove_circle_outline,
                      'Revoke Admin', Colors.orange),
                _popItem('delete', Icons.person_remove_outlined,
                    'Remove from Org', Colors.red),
              ],
              onSelected: (v) {
                switch (v) {
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
          )
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 13),
          )
        ],
      ),
    );
  }

  // --- Analytics Tab ---
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Member Demographics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          // Gender Distribution
          _analyticsSection(
            'Gender Distribution',
            _genderStats,
            [
              const Color(0xFF3B82F6),
              const Color(0xFFEC4899),
              Colors.grey,
            ],
          ),

          const SizedBox(height: 16),

          // Department Distribution
          _analyticsSection(
            'Department Distribution',
            _departmentStats,
            [
              const Color(0xFFA855F7),
              const Color(0xFFF59E0B),
              const Color(0xFF2DD4BF),
              const Color(0xFF6366F1),
              Colors.red
            ],
          ),

          const SizedBox(height: 16),

          // Family Distribution
          _analyticsSection(
            'Family Distribution',
            _familyStats,
            [
              _green,
              const Color(0xFF3B82F6),
              const Color(0xFFF59E0B),
              const Color(0xFFA855F7),
              const Color(0xFF2DD4BF)
            ],
          ),

          const SizedBox(height: 16),

          // Age Groups
          _analyticsSection(
            'Age Groups',
            _ageGroupStats,
            [
              const Color(0xFF7DD3FC),
              const Color(0xFF3B82F6),
              const Color(0xFF6366F1),
              const Color(0xFF7C3AED),
            ],
          ),

          const SizedBox(height: 16),

          // Occupation Status
          _analyticsSection(
            'Occupation Status',
            _occupationStats,
            [
              _green,
              const Color(0xFFF59E0B),
              const Color(0xFF3B82F6),
              Colors.grey,
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _analyticsSection(
    String title,
    Map<String, int> data,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Center(
              child: Text(
                'No data yet',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 13),
              ),
            )
          else ...[
            // Pie chart
            Center(
              child: SizedBox(
                height: 180,
                width: 180,
                child: CustomPaint(
                  painter: _PieChartPainter(data, colors),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Legend
            ...() {
              final total = data.values.reduce((a, b) => a + b);
              return data.entries.toList().asMap().entries.map((e) {
                final color = colors[e.key % colors.length];
                final pct = (e.value.value / total * 100).toStringAsFixed(1);
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value.key,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13),
                          ),
                        ),
                        Text(
                          '$pct% (${e.value.value})',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        )
                      ],
                    ));
              }).toList();
            }(),
          ],
        ],
      ),
    );
  }

  // ---Dialogs---

  void _showAddMemberDialog() {
    final formKey = GlobalKey<FormState>();
    final firstnameController = TextEditingController();
    final surnameController = TextEditingController();
    final othernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String gender = 'Male';
    String dept = 'Not assigned';
    String family = 'Not assigned';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogHeader(
                        Icons.person_add_rounded, 'Add New Member', _green),
                    const SizedBox(height: 20),
                    _dialogInputField('First Name', firstnameController,
                        isRequired: true),
                    _dialogInputField('Surame', surnameController,
                        isRequired: true),
                    _dialogInputField('Other Name', othernameController),
                    _dialogInputField('Email', emailController,
                        isRequired: true,
                        keyboardType: TextInputType.emailAddress),
                    _dialogInputField('Phone Number', phoneController,
                        keyboardType: TextInputType.phone),
                    _dialogDropdown('Gender', gender,
                        ['Male', 'Female', 'Other'], (v) => gender = v!),
                    _dialogDropdown(
                        'Department',
                        dept,
                        ['Not assigned', ..._departmentStats.keys],
                        (v) => dept = v!),
                    _dialogDropdown(
                        'Family',
                        family,
                        ['Not assigned', ..._familyStats.keys],
                        (v) => family = v!),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _cancelBtn(() => Navigator.pop(context)),
                        const SizedBox(width: 8),
                        _confirmBtn('Add Member', _green, () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            final orgId = await OrganizationContext
                                .getCurrentOrganizationId();
                            if (orgId == null) throw 'No organization';
                            final userDoc =
                                await _firestore.collection('users').add({
                              'firstname': firstnameController.text.trim(),
                              'surname': surnameController.text.trim(),
                              'othername': othernameController.text.trim(),
                              'email': emailController.text.trim(),
                              'phoneNumber': phoneController.text.trim(),
                              'gender': gender,
                              'department': dept,
                              'family': family,
                              'createdAt': FieldValue.serverTimestamp(),
                              'role': 'user',
                              'isApproved': true,
                              'addedManually': true,
                            });
                            await _orgService.addMemberToOrganization(
                                userId: userDoc.id,
                                organizationId: orgId,
                                role: 'user',
                                isApproved: true);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            _snack('Member added successfully!',
                                color: _greenDark);
                            _loadAnalytics();
                          } catch (e) {
                            if (!context.mounted) return;
                            _snack('Error: $e', color: Colors.red.shade800);
                          }
                        })
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMemberDetails(Map<String, dynamic> userData) {
    final fn = userData['firstname'] ?? userData['firstName'] ?? '';
    final sn = userData['surname'] ?? '';
    final name = '$fn $sn'.trim();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogHeader(
                  Icons.person_outline,
                  name.isNotEmpty ? name : 'Member Details',
                  const Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow('Email', userData['email'] ?? 'N/A'),
                    _detailRow(
                        'Phone',
                        userData['phoneNumber'] ??
                            userData['phone_number'] ??
                            'N/A'),
                    _detailRow('Gender', userData['gender'] ?? 'N/A'),
                    _detailRow(
                        'Date of Birth',
                        userData['dateOfBirth'] ??
                            userData['date_of_birth'] ??
                            'N/A'),
                    _detailRow('Residence', userData['residence'] ?? 'N/A'),
                    _detailRow('Department', userData['department'] ?? 'N/A'),
                    _detailRow('Family', userData['family'] ?? 'N/A'),
                    _detailRow('Occupation', userData['occupation'] ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: _cancelBtn(() => Navigator.pop(context), label: 'Close'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
              child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ))
        ],
      ),
    );
  }

  void _showEditMemberDialog(String userId, Map<String, dynamic> userData) {
    final firstname = userData['firstname'] ?? userData['firstName'] ?? '';
    final surname = userData['surname'] ?? '';

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
        builder: (context, setDialogState) => Dialog(
          backgroundColor: _surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogHeader(
                        Icons.edit_outlined,
                        'Edit: $firstname $surname'.trim(),
                        const Color(0xFF3B82F6)),
                    const SizedBox(height: 20),
                    _dialogEditField(firstnameController, 'First Name'),
                    _dialogEditField(surnameController, 'Surname'),
                    _dialogEditField(phonenumberController, 'Phone Number',
                        type: TextInputType.phone,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10)
                        ]),
                    _dialogEditField(residenceController, 'Residence'),
                    _dialogEditField(occupationController, 'Occupation'),
                    _dialogEditField(familyController, 'Family'),
                    _dialogEditField(departmentController, 'Department'),
                    _dialogEditField(placeofworkController, 'Place of Work'),
                    _dialogEditField(
                        placeofschoolController, 'Place of School'),
                    _dialogEditField(
                        courseofstudyController, 'Course of Study'),
                    if (isSaving)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(
                          color: _green,
                          backgroundColor: _green.withOpacity(0.1),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _cancelBtn(
                            isSaving ? null : () => Navigator.pop(context)),
                        const SizedBox(width: 8),
                        _confirmBtn(
                            'Save Changes',
                            _green,
                            isSaving
                                ? null
                                : () async {
                                    setDialogState(() => isSaving = true);
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(userId)
                                          .update({
                                        'firstname':
                                            firstnameController.text.trim(),
                                        'surname':
                                            surnameController.text.trim(),
                                        'residence': residenceController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : residenceController.text.trim(),
                                        'occupation': occupationController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : occupationController.text.trim(),
                                        'family':
                                            familyController.text.trim().isEmpty
                                                ? null
                                                : familyController.text.trim(),
                                        'department': departmentController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : departmentController.text.trim(),
                                        'placeOfWork': placeofworkController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : placeofworkController.text.trim(),
                                        'placeOfSchool': placeofschoolController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : placeofschoolController.text
                                                .trim(),
                                        'courseOfStudy': courseofstudyController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : courseofstudyController.text
                                                .trim(),
                                      });
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      _snack('Member updated',
                                          color: _greenDark);
                                    } catch (e) {
                                      setDialogState(() => isSaving = false);
                                      if (!context.mounted) return;
                                      _snack('Error: $e',
                                          color: Colors.red.shade800);
                                    }
                                  })
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Admin actions

  Future<void> _promoteToAdmin(String membershipId) async {
    final confirm = await _confirmDialog('Promote to Admin',
        'This user will need approval before gaining admin access.');

    if (confirm != true) return;

    await _firestore
        .collection('organization_members')
        .doc(membershipId)
        .update({'role': 'admin', 'isApproved': false});

    if (mounted) _snack('User promoted - pending approval');
  }

  Future<void> _approveAdmin(String membershipId) async {
    await _orgService.approveAdmin(membershipId);
    if (mounted) _snack('Admin approved', color: _greenDark);
  }

  Future<void> _rejectAdmin(String membershipId) async {
    await _firestore
        .collection('organization_members')
        .doc(membershipId)
        .update({'role': 'user', 'isApproved': false});
    if (mounted) _snack('Admin request rejected');
  }

  Future<void> _revokeAdmin(String membershipId) async {
    await _orgService.revokeAdmin(membershipId);
    if (mounted) _snack('Admin privileges revoked');
  }

  Future<void> _removeMember(String membershipId) async {
    final confirm = await _confirmDialog(
        'Remove Member', 'Remove this member from the organization?');

    if (confirm != true) return;
    await _firestore
        .collection('organization_members')
        .doc(membershipId)
        .delete();
    if (mounted) _snack('Member removed', color: Colors.red.shade700);
  }

  Future<bool?> _confirmDialog(String title, String body) {
    return showDialog(
        context: context,
        builder: (_) => Dialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      body,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _cancelBtn(() => Navigator.pop(context, false)),
                        const SizedBox(width: 8),
                        _confirmBtn('Confirm', _green,
                            () => Navigator.pop(context, true)),
                      ],
                    )
                  ],
                ),
              ),
            ));
  }

  // Dialog widget helpers

  Widget _dialogHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ))
      ],
    );
  }

  Widget _dialogInputField(String label, TextEditingController ctrl,
      {bool isRequired = false,
      TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(color: _green, fontSize: 12),
                )
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: _green,
            validator: isRequired
                ? (v) => v?.trim().isEmpty ?? true ? 'Required' : null
                : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _green)),
            ),
          )
        ],
      ),
    );
  }

  Widget _dialogEditField(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: type,
            inputFormatters: formatters,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: _green,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _green)),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dialogDropdown(String label, String value, List<String> items,
    void Function(String?) onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
            initialValue: value,
            dropdownColor: const Color(0xFF1A2A1A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            iconEnabledColor: Colors.white.withOpacity(0.4),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _green)),
            ),
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: onChanged)
      ],
    ),
  );
}

Widget _cancelBtn(VoidCallback? onTap, {String label = 'Cancel'}) {
  return TextButton(
      onPressed: onTap,
      style:
          TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.4)),
      child: Text(label));
}

Widget _confirmBtn(String label, Color color, VoidCallback? onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
          color: onTap == null ? color.withOpacity(0.4) : color,
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    ),
  );
}

// Custom pie chart painter
class _PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  _PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.reduce((a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const pi = 3.14159;

    double startAngle = -90 * (pi / 180); // from the top

    // Outer ring
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, bgPaint);

    data.entries.toList().asMap().forEach((index, entry) {
      final sweepAngle = (entry.value / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.fill;

      // slightly inset so segments feel separated
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle + 0.02,
        sweepAngle - 0.04,
        true,
        paint,
      );

      startAngle += sweepAngle;
    });

    // Center hole for donut look
    final holePaint = Paint()
      ..color = _surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.48, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
