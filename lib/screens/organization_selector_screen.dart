import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  Future<void> _loadOrganizations() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        List<OrganizationModel> orgs =
            await _orgService.getUserOrganizations(user.uid);
        setState(
          () {
            _organizations = orgs;
            _isLoading = false;
          },
        );
      } catch (e) {
        print('Error loading organizations: $e');
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading organizations: $e'),
            ),
          );
        }
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
            heroTag: 'Create',
          ),
          const SizedBox(
            height: 12,
          ),
          FloatingActionButton.extended(
            onPressed: _showJoinOrganizationDialog,
            icon: const Icon(Icons.login),
            label: const Text('Join'),
            backgroundColor: Colors.blue,
            heroTag: 'Join',
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
          const SizedBox(
            height: 16,
          ),
          const Text(
            'No Organization',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
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
                org.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(org.name),
            subtitle: Text('Code: ${org.code}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await _orgService.setActiveOrganization(user.uid, org.id);
                  if (!mounted) return;
                  Navigator.pop(context, true);
                } catch (e) {
                  print('Error setting active organization: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                    ),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  void _showCreateOrganizationDialog() {
    TextEditingController nameController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
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
                        print(
                            'Creating organization: ${nameController.text.trim()}');

                        String orgId = await _orgService.createOrganization(
                          nameController.text.trim(),
                          user.uid,
                        );

                        print('Organization created with ID: $orgId');

                        await _orgService.setActiveOrganization(
                            user.uid, orgId);

                        print('Active organization set');

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        await _loadOrganizations();

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Organization created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        // Return success to caller
                        Navigator.pop(context, true);
                      } catch (e) {
                        print('Error creating organization: $e');

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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinOrganizationDialog() {
    TextEditingController codeController = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Join Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the organization code provided by your admin'),
              const SizedBox(
                height: 16,
              ),
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
                        print(
                            'Joining organization with code: ${codeController.text.trim()}');

                        bool success = await _orgService.joinOrganization(
                          codeController.text.trim(),
                          user.uid,
                        );

                        print('Join result: $success');

                        if (!context.mounted) return;

                        Navigator.pop(context); // Close dialog

                        if (success) {
                          await _loadOrganizations();

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Joined organization successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Return success to caller
                          Navigator.pop(context, true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid code or already a member'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error joining organization: $e');

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
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}
