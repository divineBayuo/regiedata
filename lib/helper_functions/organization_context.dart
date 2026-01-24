import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrganizationContext {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user's active organization Id
  static Future<String?> getCurrentOrganizationId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // Get from user's default organization Id
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      return data['defaultOrganizationId'] as String?;
    }

    // Fallback: get organization first membership
    QuerySnapshot membershipSnapshot = await _firestore
        .collection('organization_members')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (membershipSnapshot.docs.isNotEmpty) {
      return membershipSnapshot.docs.first['organizationId'] as String?;
    }
    return null;
  }

  // Check if current user is an admin in their organization
  static Future<bool> isCurrentUserAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    String? orgId = await getCurrentOrganizationId();
    if (orgId == null) return false;

    QuerySnapshot membershipSnapshot = await _firestore
        .collection('organization_members')
        .where('userId', isEqualTo: user.uid)
        .where('organizationId', isEqualTo: orgId)
        .limit(1)
        .get();

    if (membershipSnapshot.docs.isEmpty) return false;
    Map<String, dynamic> data =
        membershipSnapshot.docs.first.data() as Map<String, dynamic>;
    return data['role'] == 'admin' && data['isApproved'] == true;
  }
}
