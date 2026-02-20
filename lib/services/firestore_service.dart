import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:regie_data/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save user data to firestore
  Future<void> createUserDocument(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user document: $e');
    }
  }

  // Get user data by uid
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  // delete user document
  Future<void> deleteUserDocument(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user document: $e');
    }
  }

  // check if user is approved admin
  Future<bool> isAdmin(String uid) async {
    try {
      UserModel? user = await getUserData(uid);
      return user?.role == 'admin' && user?.isApproved == true;
    } catch (e) {
      return false;
    }
  }

  // Get all users in organization via organization members
  Stream<List<UserModel>> getOrganizationUsers(String organizationId) {
    return _db
        .collection('organization_members')
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<UserModel> users = [];
      for (var doc in snapshot.docs) {
        String userId = doc['userId'];
        DocumentSnapshot userDoc =
            await _db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          users.add(UserModel.fromMap(userDoc.data() as Map<String, dynamic>));
        }
      }
      return users;
    });
  }

  /* // -------------------

  // Request to be admin
  Future<void> requestAdminRole(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({'role': 'pending_admin'});
    } catch (e) {
      throw Exception('Failed to request admin role: $e');
    }
  }

  // Approve admin: only superuser can
  Future<void> approveAdmin(String uid) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .update({'role': 'admin', 'isApproved': true});
    } catch (e) {
      throw Exception('Failed to approve admin: $e');
    }
  }

  // Get all pending admin requests for superuser
  Stream<List<UserModel>> getAllPendingAdminRequests() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'pending_admin')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  } */
}
