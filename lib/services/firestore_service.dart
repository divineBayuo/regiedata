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

  // Get user data
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

  // Check if user is admin
  Future<bool> isAdmin(String uid) async {
    try {
      UserModel? user = await getUserData(uid);
      return user?.role == 'admin' && user?.isApproved == true;
    } catch (e) {
      return false;
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
  }
}
