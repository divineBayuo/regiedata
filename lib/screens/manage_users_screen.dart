import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:regie_data/helper_functions/organization_context.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _loadOrgId();
  }

  Future<void> _loadOrgId() async {
    String? orgId = await OrganizationContext.getCurrentOrganizationId();
    setState(() => _orgId = orgId);
  }

  @override
  Widget build(BuildContext context) {
    if (_orgId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Users'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'All Users'),
                Tab(text: 'Pending Admins'),
                Tab(text: 'Admins')
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAllUsersList(),
                  _buildPendingAdminList(),
                  _buildAdminsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllUsersList() {
    // Get organization members first, then fetch user details
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organization_members')
          .where('organizationId', isEqualTo: _orgId!)
          .snapshots(),
      builder: (context, membershipSnapshot) {
        if (membershipSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!membershipSnapshot.hasData ||
            membershipSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No members found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: membershipSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final membershipDoc = membershipSnapshot.data!.docs[index];
            final membershipData = membershipDoc.data() as Map<String, dynamic>;
            final userId = membershipData['userId'] as String;
            final role = membershipData['role'] as String? ?? 'user';
            final isApproved = membershipData['isApproved'] as bool? ?? false;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                // Support both field name variants
                final firstname =
                    userData['firstname'] ?? userData['firstName'] ?? 'Unknown';
                final surname = userData['surname'] ?? '';
                final fullname = '$firstname $surname'.trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRoleColor(role, isApproved),
                      child: Text(
                        fullname.isNotEmpty ? fullname[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(fullname),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userData['email'] ?? ''),
                        Text(
                          _getRoleText(role, isApproved),
                          style: TextStyle(
                            color: _getRoleColor(role, isApproved),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing:
                        /* _buildUserActions(membershipData, membershipDoc.id), */
                        PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'view') {
                          _showUserDetails(context, userData, membershipData);
                        } else if (value == 'edit') {
                          _showEditUserDialog(context, userId, userData);
                        } else if (value == 'approve') {
                          _approveAdmin(context, membershipDoc.id);
                        } else if (value == 'revoke') {
                          _revokeAdmin(context, membershipDoc.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'view', child: Text('View Details')),
                        const PopupMenuItem(
                            value: 'edit', child: Text('Edit Details')),
                        if (role == 'admin' && !isApproved)
                          const PopupMenuItem(
                              value: 'approve', child: Text('Approve Admin')),
                        if (role == 'admin' && isApproved)
                          const PopupMenuItem(
                              value: 'revoke',
                              child: Text('Revoke Admin',
                                  style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingAdminList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organization_members')
          .where('organizationId', isEqualTo: _orgId!)
          .where('role', isEqualTo: 'admin')
          .where('isApproved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(
                  height: 16,
                ),
                Text(
                  'No pending admin requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final memberData = doc.data() as Map<String, dynamic>;
            final userId = memberData['userId'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox.shrink();
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                final firstname =
                    userData['firstname'] ?? userData['firstName'] ?? 'Unknown';
                final surname = userData['surname'] ?? '';
                final fullname = '$firstname $surname'.trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(
                        Icons.hourglass_empty,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(fullname),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userData['email'] ?? ''),
                        const Text(
                          'Requested admin access',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _approveAdmin(context, doc.id),
                          icon: const Icon(
                            Icons.check,
                            color: Colors.green,
                          ),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          onPressed: () => _rejectAdmin(context, doc.id),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                          ),
                          tooltip: 'Reject',
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAdminsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organization_members')
          .where('organizationId', isEqualTo: _orgId!)
          .where('role', isEqualTo: 'admin')
          .where('isApproved', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No admins found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final memberData = doc.data() as Map<String, dynamic>;
            final userId = memberData['userId'] as String;

            return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc('userId')
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox.shrink();
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox.shrink();

                  final firstname = userData['firstname'] ??
                      userData['firstName'] ??
                      'Unknown';
                  final surname = userData['surname'] ?? '';
                  final fullname = '$firstname $surname'.trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(fullname),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userData['email'] ?? ''),
                          const Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showEditUserDialog(context, userId, userData),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            onPressed: () => _revokeAdmin(context, doc.id),
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            tooltip: 'Revoke Admin',
                          ),
                        ],
                      ),
                    ),
                  );
                });
          },
        );
      },
    );
  }

  /* Widget _buildUserActions(
      Map<String, dynamic> membershipData, String membershipId) {
    return PopupMenuButton(
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'view', child: Text('View Details')),
        if (membershipData['role'] == 'admin' && !membershipData['isApproved'])
          const PopupMenuItem(value: 'approve', child: Text('Approve Admin')),
        if (membershipData['role'] == 'admin' && membershipData['isApproved'])
          const PopupMenuItem(value: 'revoke', child: Text('Revoke Admin')),
      ],
      onSelected: (value) {
        if (value == 'approve') {
          _approveAdmin(context, membershipId);
        } else if (value == 'revoke') {
          _revokeAdmin(context, membershipId);
        }
      },
    );
  } */

  Color _getRoleColor(String role, bool isApproved) {
    if (role == 'admin' && isApproved) return Colors.green;
    if (role == 'admin' && !isApproved) return Colors.orange;
    return Colors.blue;
  }

  String _getRoleText(String role, bool isApproved) {
    if (role == 'admin' && isApproved) return 'Admin';
    if (role == 'admin' && !isApproved) return 'Pending Admin';
    return 'User';
  }

  void _approveAdmin(BuildContext context, String membershipId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Admin'),
        content: const Text('Grant admin privileges to this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('organization_members')
                  .doc(membershipId)
                  .update({'isApproved': true});
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin approved successfully'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectAdmin(BuildContext context, String membershipId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Admin Request'),
        content:
            const Text('This will revert the user to regular user status.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('organization_members')
                  .doc(membershipId)
                  .update({
                'role': 'user',
                'isApproved': true,
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin request rejected'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _revokeAdmin(BuildContext context, String membershipId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Admin'),
        content:
            const Text('Are you sure you want to revoke admin privileges?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('organization_members')
                  .doc(membershipId)
                  .update({'role': 'user', 'isApproved': true});
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin privileges revoked'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(
              'Revoke',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> userData,
      Map<String, dynamic> memberData) {
    final firstname =
        userData['firstname'] ?? userData['firstName'] ?? 'Unknown';
    final surname = userData['surname'] ?? '';
    final fullname = '$firstname $surname'.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fullname),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', userData['email']),
              _buildDetailRow(
                  'Phone', userData['phoneNumber'] ?? userData['phone_number']),
              _buildDetailRow('Gender', userData['gender']),
              _buildDetailRow('Residence', userData['residence']),
              _buildDetailRow('Occupation', userData['occupation']),
              _buildDetailRow('Family', userData['family']),
              _buildDetailRow('Department', userData['department']),
              _buildDetailRow('Place of Work', userData['placeOfWork']),
              _buildDetailRow('Place of School', userData['placeOfSchool']),
              _buildDetailRow('Course of Study', userData['courseOfStudy']),
              _buildDetailRow(
                  'Role',
                  _getRoleText(memberData['role'] ?? 'user',
                      memberData['isApproved'] ?? false)),
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

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // edit user data dialog
  void _showEditUserDialog(
      BuildContext context, String userId, Map<String, dynamic> userData) {
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

  Widget _editField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text,
      List<TextInputFormatter>? formatters}) {
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
