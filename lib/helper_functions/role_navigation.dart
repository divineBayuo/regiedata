import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/organization_context.dart';
import 'package:regie_data/screens/admin_dashboard.dart';
import 'package:regie_data/screens/organization_selector_screen.dart';
import 'package:regie_data/screens/pending_admin_screen.dart';
import 'package:regie_data/screens/user_home_screen.dart';

Future<void> navigateBasedOnRole(BuildContext context) async {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  // Check if user has organization
  String? orgId = await OrganizationContext.getCurrentOrganizationId();

  if (orgId == null) {
    // No organization - navigate to selector
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const OrganizationSelectorScreen()),
    );
    return;
  }

  // Get user's membership in current organization
  QuerySnapshot membershipSnapshot = await FirebaseFirestore.instance
      .collection('organization_members')
      .where('userId', isEqualTo: currentUser.uid)
      .where('organizationId', isEqualTo: orgId)
      .limit(1)
      .get();

  if (membershipSnapshot.docs.isEmpty) {
    // User has defaultOrganizationId but no membership - navigate to selector
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const OrganizationSelectorScreen(),
      ),
    );
    return;
  }

  Map<String, dynamic> membershipData =
      membershipSnapshot.docs.first.data() as Map<String, dynamic>;
  String role = membershipData['role'];
  bool isApproved = membershipData['isApproved'];

  if (!context.mounted) return;

  if (role == 'admin' && isApproved) {
    // Navigate to admin dashboard
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminDashboard(),
      ),
    );
  } else if (role == 'admin' && !isApproved) {
    // Navigate to pending approval screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PendingAdminScreen(),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const UserHomeScreen(),
      ),
    );
  }
}
