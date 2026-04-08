import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/screens/admin_dashboard.dart';
import 'package:regie_data/screens/main_shell.dart';
import 'package:regie_data/screens/pending_admin_screen.dart';
import 'package:regie_data/screens/user_home_screen.dart';
import 'package:regie_data/services/organization_service.dart';

Future<void> navigateBasedOnRole(BuildContext context) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  if (!context.mounted) return;

  // Wrapped with main shell to maintain bottom nav state
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => const MainShell(initialIndex: 0),
    ),
  );
}

// Navigate based on user's role in a specific organization
// Called after user selects an organization
Future<void> navigateToOrgScreen(
  BuildContext context,
  String userId,
  String orgId,
) async {
  final orgService = OrganizationService();
  final membership = await orgService.getUserMembership(userId, orgId);

  if (membership == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not a member of this organization')),
    );
    return;
  }

  if (!context.mounted) return;

  // Navigate based on role and approval status in this organization
  if (membership.role == 'admin' && membership.isApproved) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainShell(
          initialIndex: 0,
          homeWidget: AdminDashboard(),
        ),
      ),
    );
  } else if (membership.role == 'admin' && !membership.isApproved) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainShell(
          initialIndex: 0,
          homeWidget: PendingAdminScreen(),
        ),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainShell(
          initialIndex: 0,
          homeWidget: UserHomeScreen(),
        ),
      ),
    );
  }
}
