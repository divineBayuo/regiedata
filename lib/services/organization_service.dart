import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:regie_data/models/organization_membership_model.dart';
import 'package:regie_data/models/organization_model.dart';

class OrganizationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate unique organization code
  String _generateOrgCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Create new organization
  Future<String> createOrganization(String name, String createdBy) async {
    String code = _generateOrgCode();

    // Check if the code already exists
    while (await _codeExists(code)) {
      code = _generateOrgCode();
    }

    DocumentReference orgRef =
        await _firestore.collection('organizations').add({
      'name': name,
      'code': code,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'settings': {},
    });

    // Add creator as admin
    await addMemberToOrganization(
      userId: createdBy,
      organizationId: orgRef.id,
      role: 'admin',
      isApproved: true,
    );

    return orgRef.id;
  }

  Future<bool> _codeExists(String code) async {
    QuerySnapshot snapshot = await _firestore
        .collection('organizations')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Join organization with code
  Future<bool> joinOrganization(String code, String userId,
      {String role = 'user'}) async {
    try {
      QuerySnapshot orgSnapshot = await _firestore
          .collection('organizations')
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (orgSnapshot.docs.isEmpty) {
        return false; // Code is invalid
      }

      String organizationId = orgSnapshot.docs.first.id;

      // Check if already a member
      QuerySnapshot membershipSnapshot = await _firestore
          .collection('organization_members')
          .where('userId', isEqualTo: userId)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (membershipSnapshot.docs.isNotEmpty) {
        return false; // Already a member
      }

      // Add as member
      await addMemberToOrganization(
        userId: userId,
        organizationId: organizationId,
        role: role,
        isApproved: role == 'user',
      );

      return true;
    } catch (e) {
      print('Error joining organization: $e');
      return false;
    }
  }

  // Add member to organization
  Future<void> addMemberToOrganization({
    required String userId,
    required String organizationId,
    required String role,
    required bool isApproved,
    Map<String, dynamic>? personalData,
  }) async {
    await _firestore.collection('organization_members').add({
      'userId': userId,
      'organizationId': organizationId,
      'role': role,
      'isApproved': isApproved,
      'joinedAt': FieldValue.serverTimestamp(),
      'personalData': personalData ?? {},
    });
  }

  // Get user's organizations
  Future<List<OrganizationModel>> getUserOrganizations(String userId) async {
    // Get all memberships
    QuerySnapshot membershipSnapshot = await _firestore
        .collection('organization_members')
        .where('userId', isEqualTo: userId)
        .get();

    List<OrganizationModel> organizations = [];

    for (var membershipDoc in membershipSnapshot.docs) {
      String orgId = membershipDoc['organizationId'];
      DocumentSnapshot orgDoc =
          await _firestore.collection('organizations').doc(orgId).get();

      if (orgDoc.exists) {
        organizations.add(
          OrganizationModel.fromMap(
            orgDoc.data() as Map<String, dynamic>,
            orgDoc.id,
          ),
        );
      }
    }

    return organizations;
  }

  // Get user's role in organization
  Future<OrganizationMembershipModel?> getUserMembership(
    String userId,
    String organizationId,
  ) async {
    QuerySnapshot snapshot = await _firestore
        .collection('organization_members')
        .where('userId', isEqualTo: userId)
        .where('organizationId', isEqualTo: organizationId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return OrganizationMembershipModel.fromMap(
      snapshot.docs.first.data() as Map<String, dynamic>,
      snapshot.docs.first.id,
    );
  }

  // Check if user is admin in organization
  Future<bool> isOrganizationAdmin(String userId, String organizationId) async {
    OrganizationMembershipModel? membership =
        await getUserMembership(userId, organizationId);
    return membership?.role == 'admin' && membership?.isApproved == true;
  }

  // Switch active organization
  Future<void> setActiveOrganization(
      String userId, String organizationId) async {
    await _firestore.collection('users').doc(userId).update({
      'defaultOrganizationId': organizationId,
    });
  }

  // Get active organization
  Future<String?> getActiveOrganization(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return userDoc['defaultOrganizationId'] as String?;
    }
    return null;
  }

  Future<String?> getOrganizationIdByCode(String code) async {
    QuerySnapshot snapshot = await _firestore
        .collection('organizations')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }
}
