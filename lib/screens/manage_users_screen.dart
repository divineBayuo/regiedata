import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                Tab(
                  text: 'All Users',
                ),
                Tab(
                  text: 'Pending Admins',
                ),
                Tab(
                  text: 'Admins',
                )
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No users found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(data['role']),
                  child: Text(
                    (data['firstName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text('${data['firstName']} ${data['surname']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? ''),
                    Text(
                      _getRoleText(data['role'], data['isApproved']),
                      style: TextStyle(
                        color: _getRoleColor(data['role']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View Details'),
                    ),
                    if (data['role'] == 'pending_admin')
                      const PopupMenuItem(
                        value: 'approve',
                        child: Text('Approve Admin'),
                      ),
                    if (data['role'] == 'admin' && data['isApproved'])
                      const PopupMenuItem(
                        value: 'revoke',
                        child: Text('Revoke Admin'),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'approve') {
                      _approveAdmin(context, doc.id);
                    } else if (value == 'revoke') {
                      _revokeAdmin(context, doc.id);
                    } else if (value == 'view') {
                      _showUserDetails(context, data);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingAdminList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'pending_admin')
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
                  'No pending Admin Requests',
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
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

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
                title: Text('${data['firstName']} ${data['surname']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? ''),
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
  }

  Widget _buildAdminsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
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
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

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
                title: Text('${data['firstName']} ${data['surname']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? ''),
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
                trailing: IconButton(
                  onPressed: () => _revokeAdmin(context, doc.id),
                  icon: const Icon(
                    Icons.remove_circle,
                    color: Colors.red,
                  ),
                  tooltip: 'Revoke Admin',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.green;
      case 'pending_admin':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getRoleText(String? role, bool? isApproved) {
    if (role == 'admin' && isApproved == true) {
      return 'Admin';
    } else if (role == 'pending_admin') {
      return 'Pending Admin';
    } else {
      return 'User';
    }
  }

  void _approveAdmin(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Admin'),
        content: const Text(
            'Are you sure you want to approve this user as an admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update(
                {
                  'role': 'admin',
                  'isApproved': true,
                },
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin approved successfully'),
                ),
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectAdmin(BuildContext context, String userId) {
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
                  .collection('users')
                  .doc(userId)
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _revokeAdmin(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Admin'),
        content: const Text('Are you sure you want to revoke admin privileges?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update(
                {
                  'role': 'user',
                  'isApproved': true,
                },
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin privileges revoked'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Revoke',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data['firstName']} ${data['surname']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', data['email']),
              _buildDetailRow('Phone', data['phoneNumber']),
              _buildDetailRow('Gender', data['gender']),
              _buildDetailRow('Residence', data['residence']),
              _buildDetailRow('Occupation', data['occupation']),
              _buildDetailRow('Family', data['family']),
              _buildDetailRow('Department', data['department']),
              _buildDetailRow(
                  'Role', _getRoleText(data['role'], data['isApproved'])),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.toString()),
          ),
        ],
      ),
    );
  }
}
