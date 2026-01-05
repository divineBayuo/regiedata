import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/models/user_model.dart';
import 'package:regie_data/screens/admin_dashboard.dart';
import 'package:regie_data/screens/pending_approval_screen.dart';
import 'package:regie_data/screens/user_home_screen.dart';
import 'package:regie_data/services/firestore_service.dart';

Future<void> navigateBasedOnRole(BuildContext context) async {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  FirestoreService firestoreService = FirestoreService();
  UserModel? userData = await firestoreService.getUserData(currentUser.uid);

  if (userData == null) return;

  if (!context.mounted) return;

  if (userData.role == 'admin' && userData.isApproved) {
    // Navigate to admin dashboard
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> const AdminDashboard()));
  } else if (userData.role == 'pending_admin') {
    // Navigate to pending approval screen
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> const PendingApprovalScreen()));
  } else {
    // Navigate to regular user home screen
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> const UserHomeScreen()));
  }
}