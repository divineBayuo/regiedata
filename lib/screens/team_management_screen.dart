import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/screens/subscription_screen.dart';
import 'package:regie_data/services/subscription_service.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

// Business plan - manage sub-admins with granular permissions
// create/edit depts and set per-role access controls

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userPlan = 'free';
  bool _isCheckingPlan = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userPlan = await SubscriptionService.getUserPlan(uid);
    }
    if (mounted) setState(() => _isCheckingPlan = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text('Team Management',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              Divider(height: 1, color: Colors.white.withOpacity(0.06)),
              TabBar(
                controller: _tabController,
                indicatorColor: _green,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: _green,
                unselectedLabelColor: Colors.white.withOpacity(0.35),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Sub-Admins'),
                  Tab(text: 'Departments'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isCheckingPlan
          ? const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2),
            )
          : _userPlan == 'business'
              ? TabBarView(controller: _tabController, children: [
                  _SubAdminsTab(),
                  _DepartmentsTab(),
                ])
              : _upgradeWall(),
    );
  }

  Widget _upgradeWall() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: _green, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Business Plan Feature',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Team Management is available on the Business plan. '
              'Manage sub-admins with granular permissions and '
              'create custom departments. ',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
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
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Center(
                  child: Text('Upgrade to Business',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --sub-admins tab---
class _SubAdminsTab extends StatefulWidget {
  @override
  State<_SubAdminsTab> createState() => __SubAdminsTabState();
}

class __SubAdminsTabState extends State<_SubAdminsTab> {
  final _db = FirebaseFirestore.instance;

  // Permissions model - stored in organization_members doc
  static const _allPermissions = [
    _Permission('manage_sessions', 'Manage Sessions',
        'Create, edit and end attendance sessions', Icons.qr_code_rounded),
    _Permission('view_attendance', 'View Attendance',
        'Access all attendance recors', Icons.list_alt_rounded),
    _Permission('manage_members', 'Manage Members',
        'Add, edit and remove members', Icons.manage_accounts_outlined),
    _Permission('view_analytics', 'View Analytics',
        'Access analytics and reports', Icons.bar_chart_rounded),
    _Permission('export_data', 'Export Data', 'Export CSV and reports',
        Icons.download_rounded),
    _Permission(
        'manage_finances',
        'Manage Finances',
        'Edit money collected on sessions',
        Icons.account_balance_wallet_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: OrganizationContext.getCurrentOrganizationId(),
      builder: (context, orgSnap) {
        if (!orgSnap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2));
        }
        final orgId = orgSnap.data!;

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('organization_members')
              .where('organizationId', isEqualTo: orgId)
              .where('role', isEqualTo: 'admin')
              .where('isApproved', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: _green, strokeWidth: 2));
            }

            final docs = snap.data?.docs ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _green, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Assign granular permissions to admins. '
                          'Tap an admin card to configure their access.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (docs.isEmpty)
                  _emptyState(Icons.admin_panel_settings_outlined,
                      'No admins yet', 'Promote members to admin first.')
                else
                  ...docs.map(
                    (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = data['userId'] as String;
                      final permissions =
                          List<String>.from(data['permissions'] as List? ?? []);

                      return FutureBuilder<DocumentSnapshot>(
                        future: _db.collection('users').doc(userId).get(),
                        builder: (context, uSnap) {
                          if (!uSnap.hasData) return const SizedBox.shrink();
                          final ud =
                              uSnap.data!.data() as Map<String, dynamic>? ?? {};
                          final fn = ud['firstname'] ?? ud['firstName'] ?? '';
                          // final sn = ud['surname'] ?? '';
                          final name = '$fn sn'.trim();

                          return _adminCard(
                            membershipId: doc.id,
                            userId: userId,
                            name: name.isNotEmpty ? name : 'Admin',
                            email: ud['email'] ?? '',
                            permissions: permissions,
                            orgId: orgId,
                          );
                        },
                      );
                    },
                  )
              ],
            );
          },
        );
      },
    );
  }

  Widget _adminCard({
    required String membershipId,
    required String userId,
    required String name,
    required String email,
    required List<String> permissions,
    required String orgId,
  }) {
    final grantedCount = permissions.length;
    final totalCount = _allPermissions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withOpacity(0.2)),
                ),
                child: Center(
                  child: Text(
                    name.isEmpty ? name[0].toUpperCase() : 'A',
                    style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(email,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12)),
                  ],
                ),
              ),
              // Permission count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: grantedCount == totalCount
                        ? _green.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '$grantedCount/$totalCount',
                  style: TextStyle(
                      color: grantedCount == totalCount
                          ? _green
                          : Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    _editPermissions(context, membershipId, name, permissions),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFF3B82F6), size: 16),
                ),
              ),
            ],
          ),
          if (permissions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissions.map((p) {
                final perm =
                    _allPermissions.where((pp) => pp.id == p).firstOrNull;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withOpacity(0.15)),
                  ),
                  child: Text(perm?.label ?? p,
                      style: TextStyle(
                          color: _green.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                );
              }).toList(),
            )
          ]
        ],
      ),
    );
  }

  void _editPermissions(BuildContext context, String membershipId,
      String adminName, List<String> current) {
    final selected = Set<String>.from(current);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDS) => Dialog(
          backgroundColor: _surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: _green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Permissions - $adminName',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 20),
                ..._allPermissions.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected.contains(p.id)
                              ? _green.withOpacity(0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected.contains(p.id)
                                ? _green.withOpacity(0.2)
                                : Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: selected.contains(p.id),
                          activeColor: _green,
                          checkColor: Colors.white,
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          dense: true,
                          title: Text(p.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(p.description,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 11)),
                          secondary: Icon(p.icon, color: _green, size: 18),
                          onChanged: (v) {
                            setDS(() {
                              if (v == true) {
                                selected.add(p.id);
                              } else {
                                selected.remove(p.id);
                              }
                            });
                          },
                        ),
                      ),
                    )),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.4)),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        await _db
                            .collection('organization_members')
                            .doc(membershipId)
                            .update({'permissions': selected.toList()});
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Save',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --departments tab---
class _DepartmentsTab extends StatefulWidget {
  @override
  State<_DepartmentsTab> createState() => __DepartmentsTabState();
}

class __DepartmentsTabState extends State<_DepartmentsTab> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: OrganizationContext.getCurrentOrganizationId(),
      builder: (context, orgSnap) {
        if (!orgSnap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _green, strokeWidth: 2));
        }
        final orgId = orgSnap.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('organizations').doc(orgId).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: _green, strokeWidth: 2));
            }

            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final departments =
                List<String>.from(data['departments'] as List? ?? []);
            final families = List<String>.from(data['families'] as List? ?? []);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _groupCard(
                  title: 'Departments',
                  icon: Icons.category_outlined,
                  color: const Color(0xFF6366F1),
                  items: departments,
                  onAdd: (name) async {
                    departments.add(name);
                    await _db
                        .collection('organizations')
                        .doc(orgId)
                        .update({'departments': departments});
                  },
                  onDelete: (name) async {
                    departments.remove(name);
                    await _db
                        .collection('organizations')
                        .doc(orgId)
                        .update({'departments': departments});
                  },
                ),
                const SizedBox(height: 16),
                _groupCard(
                  title: 'Families / Groups',
                  icon: Icons.people_outline,
                  color: const Color(0xFFA855F7),
                  items: families,
                  onAdd: (name) async {
                    families.add(name);
                    await _db
                        .collection('organizations')
                        .doc(orgId)
                        .update({'families': families});
                  },
                  onDelete: (name) async {
                    families.remove(name);
                    await _db
                        .collection('organizations')
                        .doc(orgId)
                        .update({'families': families});
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _groupCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required Future<void> Function(String) onAdd,
    required Future<void> Function(String) onDelete,
  }) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddDialog(context, title, onAdd),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_rounded, color: color, size: 18),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => _itemChip(item, color, onDelete))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text('No $title added yet.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _itemChip(
      String label, Color color, Future<void> Function(String) onDelete) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => onDelete(label),
            child: Icon(Icons.close_rounded, color: color, size: 14),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(
      BuildContext context, String type, Future<void> Function(String) onAdd) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to $type',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: _green,
                decoration: InputDecoration(
                  hintText: 'e.g., Youth Wing',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _green)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.4)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final name = ctrl.text.trim();
                      if (name.isEmpty) return;
                      await onAdd(name);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Add',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Helpers
Widget _emptyState(IconData icon, String title, String sub) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(icon, size: 48, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(sub,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 13)),
        ],
      ),
    );

// Permission model
class _Permission {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  const _Permission(
    this.id,
    this.label,
    this.description,
    this.icon,
  );
}
