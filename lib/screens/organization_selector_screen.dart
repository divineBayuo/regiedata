import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/models/organization_model.dart';
import 'package:regie_data/models/plan_limits.dart';
import 'package:regie_data/screens/subscription_screen.dart';
import 'package:regie_data/services/organization_service.dart';
import 'package:regie_data/services/subscription_service.dart';

// Theme tokens
const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class OrganizationSelectorScreen extends StatefulWidget {
  const OrganizationSelectorScreen({super.key});

  @override
  State<OrganizationSelectorScreen> createState() =>
      _OrganizationSelectorScreenState();
}

class _OrganizationSelectorScreenState extends State<OrganizationSelectorScreen>
    with SingleTickerProviderStateMixin {
  final OrganizationService _orgService = OrganizationService();
  List<OrganizationModel> _organizations = [];
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadOrganizations();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
      _fadeController.forward(from: 0);
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false, // removes back button
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_green, _greenDark]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/regie_splash.png',
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Regie Data',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _badgeChip('Select Organization'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _green.withOpacity(0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _green,
                    strokeWidth: 2.5,
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: _organizations.isEmpty
                      ? _buildEmptyState()
                      : _buildOrganizationList(),
                )
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Create FAB
          _styledFab(
            onTap: _showCreateOrganizationDialog,
            icon: Icons.add_rounded,
            label: 'Create',
            heroTag: 'create',
            color: _green,
          ),
          const SizedBox(height: 12),
          // Join FAB
          _styledFab(
            onTap: _showJoinOrganizationDialog,
            icon: Icons.login_rounded,
            label: 'Join',
            heroTag: 'join',
            color: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _styledFab({
    required String label,
    required IconData icon,
    required Color color,
    required String heroTag,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Icon(
              Icons.business_outlined,
              size: 52,
              color: Colors.white.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Organization Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new organization or join an existing one',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildOrganizationList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        final initial = org.name.isNotEmpty ? org.name[0].toUpperCase() : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              try {
                await _orgService.setActiveOrganization(user.uid, org.id);
                if (!mounted) return;
                await navigateToOrgScreen(context, user.uid, org.id);
              } catch (e) {
                Logger().e('Error setting active organization: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_green, _greenDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Code: ${org.code}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12,
                          ),
                        )
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.2),
                    size: 14,
                  ),
                ],
              ),
            ),
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
        builder: (context, setDialogState) => _styledDialog(
          title: 'Create Organization',
          icon: Icons.add_business_outlined,
          iconColor: _green,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogInput(
                controller: nameController,
                label: 'Organization Name',
                hint: 'e.g., Liberty Centre AG',
                enabled: !isCreating,
              ),
              if (isCreating) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: _green, strokeWidth: 2),
                const SizedBox(height: 8),
                Text(
                  'Creating...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            _dialogCancel(() => Navigator.pop(context), disabled: isCreating),
            _dialogConfirm(
              label: 'Create',
              color: _green,
              disabled: isCreating,
              onTap: () async {
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

                // --Plan cap check
                final plan = await SubscriptionService.getUserPlan(user.uid);
                final maxOrgs = PlanLimits.maxOrganizations(plan);
                if (_organizations.length >= maxOrgs) {
                  setDialogState(() => isCreating = false);
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: const Color(0xFF111811),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                color: Color(0xFF22C55E), size: 36),
                            const SizedBox(height: 16),
                            Text(
                              plan == 'free'
                                  ? 'Free plan allows 1 organization.'
                                  : 'Pro plan allows up to $maxOrgs organizations.',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SubscriptionScreen()));
                              },
                              child: Container(
                                width: double.infinity,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF22C55E),
                                    Color(0xFF16A34A)
                                  ]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text('Upgrade Plan',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                  return;
                }

                try {
                  Logger().e(
                      'Creating organization: ${nameController.text.trim()}');

                  final orgId = await _orgService.createOrganization(
                    nameController.text.trim(),
                    user.uid,
                  );

                  Logger().e('Organization created with ID: $orgId');

                  await _orgService.setActiveOrganization(user.uid, orgId);

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
        builder: (context, setDialogState) => _styledDialog(
          title: 'Join Organization',
          icon: Icons.login_rounded,
          iconColor: const Color(0xFF3B82F6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the organization code provided by your admin',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 13),
              ),
              const SizedBox(height: 16),
              _dialogInput(
                controller: codeController,
                label: 'Organization Code',
                hint: 'e.g., ABC12345',
                capitalization: TextCapitalization.characters,
                enabled: !isJoining,
              ),
              if (isJoining) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                    color: Color(0xFF3B82F6), strokeWidth: 2),
                const SizedBox(height: 8),
                Text(
                  'Joining organization...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            _dialogCancel(() => Navigator.pop(context)),
            _dialogConfirm(
              label: 'Join',
              color: const Color(0xFF3B82F6),
              disabled: isJoining,
              onTap: () async {
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
                    final orgId = await _orgService
                        .getOrganizationIdByCode(codeController.text.trim());

                    if (orgId != null) {
                      await _orgService.setActiveOrganization(user.uid, orgId);

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
            ),
          ],
        ),
      ),
    ).then((_) => _loadOrganizations());
  }

  // Styled builders inside dialogs
  Widget _styledDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: a,
                      ))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _dialogInput({
    required TextEditingController controller,
    required String hint,
    required String label,
    bool enabled = true,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          textCapitalization: capitalization,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: _green,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _green),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogCancel(VoidCallback onTap, {bool disabled = false}) {
    return TextButton(
      onPressed: disabled ? null : onTap,
      style: TextButton.styleFrom(
          foregroundColor: Colors.white.withOpacity(0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: const Text(
        'Cancel',
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _dialogConfirm({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? color.withOpacity(0.4) : color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
