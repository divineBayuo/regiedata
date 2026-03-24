import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/models/organization_model.dart';
import 'package:regie_data/services/organization_service.dart';

class OrganizationSelectorScreen extends StatefulWidget {
  const OrganizationSelectorScreen({super.key});

  @override
  State<OrganizationSelectorScreen> createState() =>
      _OrganizationSelectorScreenState();
}

class _OrganizationSelectorScreenState
    extends State<OrganizationSelectorScreen> {
  final OrganizationService _orgService = OrganizationService();
  List<OrganizationModel> _organizations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final orgs = await _orgService.getUserOrganizations(user.uid);
      setState(
        () {
          _organizations = orgs;
          _isLoading = false;
        },
      );
    } catch (e) {
      Logger().e('Error loading organizations: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading organizations: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Organization'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // removes back button
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _organizations.isEmpty
              ? _buildEmptyState()
              : _buildOrganizationList(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _showCreateOrganizationDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
            backgroundColor: Colors.green,
            heroTag: 'create',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showJoinOrganizationDialog,
            icon: const Icon(Icons.login),
            label: const Text('Join'),
            backgroundColor: Colors.blue,
            heroTag: 'join',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Organization Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new organization or join an existing one',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildOrganizationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        OrganizationModel org = _organizations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                org.name.isNotEmpty ? org.name[0].toUpperCase() : '0',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(org.name),
            subtitle: Text('Code: ${org.code}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              try {
                // set active org
                await _orgService.setActiveOrganization(user.uid, org.id);

                if (!mounted) return;

                // Navigate to appropriate screen based on role in this active org
                await navigateToOrgScreen(context, user.uid, org.id);
              } catch (e) {
                Logger().e('Error setting active organization: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  void _showCreateOrganizationDialog() {
    final nameController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Create Organization',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: TextStyle(fontWeight: FontWeight.w600),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  hintText: 'e.g., Liberty Centre AG',
                  border: OutlineInputBorder(),
                ),
                enabled: !isCreating,
              ),
              if (isCreating) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Creating Organization...'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter organization name'),
                          ),
                        );
                        return;
                      }

                      User? user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No user logged in'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        Logger().e(
                            'Creating organization: ${nameController.text.trim()}');

                        final orgId = await _orgService.createOrganization(
                          nameController.text.trim(),
                          user.uid,
                        );

                        Logger().e('Organization created with ID: $orgId');

                        await _orgService.setActiveOrganization(
                            user.uid, orgId);

                        Logger().e('Active organization set');

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        // Navigate to dadshboard for this new org as admin
                        await navigateToOrgScreen(context, user.uid, orgId);
                      } catch (e) {
                        Logger().e('Error creating organization: $e');

                        setDialogState(() => isCreating = false);

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
              child: const Text(
                'Create',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _loadOrganizations());
  }

  void _showJoinOrganizationDialog() {
    final codeController = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Join Organization',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the organization code provided by your admin'),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Organization Code',
                  hintText: 'e.g., ABC12345',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: !isJoining,
              ),
              if (isJoining) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Joining organization...'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isJoining
                  ? null
                  : () async {
                      if (codeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter organization code')),
                        );
                        return;
                      }

                      User? user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No user logged in')),
                        );
                        return;
                      }

                      setDialogState(() => isJoining = true);

                      try {
                        Logger().e(
                            'Joining organization with code: ${codeController.text.trim()}');

                        // fetch user's role from the user's doc
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get();
                        final userData = userDoc.data();
                        final userRole = userData?['role'] as String? ?? 'user';

                        Logger().e('User role from document: $userRole');

                        final success = await _orgService.joinOrganization(
                          codeController.text.trim(),
                          user.uid,
                          role: userRole,
                        );

                        Logger().e('Join result: $success');

                        if (!context.mounted) return;

                        Navigator.pop(context); // Close dialog

                        if (success) {
                          // Get the orgid of the org we just joined
                          final orgId =
                              await _orgService.getOrganizationIdByCode(
                                  codeController.text.trim());

                          if (orgId != null) {
                            await _orgService.setActiveOrganization(
                                user.uid, orgId);

                            if (!context.mounted) return;

                            // Navigate to appropriate screen for this org
                            await navigateToOrgScreen(context, user.uid, orgId);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Joined successfully but could not load organizations'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            await _loadOrganizations();
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid code or already a member'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          await _loadOrganizations();
                        }
                      } catch (e) {
                        Logger().e('Error joining organization: $e');

                        setDialogState(() => isJoining = false);

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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Join',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _loadOrganizations());
  }
}
