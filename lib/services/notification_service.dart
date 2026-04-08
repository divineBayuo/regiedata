import 'package:cloud_firestore/cloud_firestore.dart';

/// Write notification documents to notifications/{userId}/items
/// so that every user has their own feed. Called every time there
/// is a trigger action

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // Write helpers
  static Future<void> _write({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> extra = const {},
  }) async {
    await _db.collection('notifications').doc(userId).collection('items').add({
      'type': type,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }

  // Public API
  /// Call when admin creates live session
  /// Sends to every member of the org except creator
  static Future<void> notifySessionStarted({
    required String orgId,
    required String orgName,
    required String eventName,
    required String createdByUid,
  }) async {
    final membersSnap = await _db
        .collection('organization_members')
        .where('organizationId', isEqualTo: orgId)
        .get();

    final futures = membersSnap.docs
        .where((d) => d['userId'] != createdByUid)
        .map((d) => _write(
              userId: d['userId'] as String,
              type: 'session_started',
              title: '🟢 Session Started - $orgName',
              body:
                  '"$eventName" is now live. Scan the QR or enter the PIN to check in.',
              extra: {'orgId': orgId, 'eventName': eventName},
            ));

    await Future.wait(futures);
  }

  /// Call when a member is promoted to admin
  static Future<void> notifyPromoted(
      {required String userId, required String orgName}) async {
    await _write(
      userId: userId,
      type: 'promoted',
      title: '⭐ Admin Request Submitted',
      body:
          'Your request to become an admin of "$orgName" is pending approval.',
      extra: {'orgName': orgName},
    );
  }

  /// Call when admin approves a pending admin
  static Future<void> notifyAdminApproved({
    required String userId,
    required String orgName,
  }) async {
    await _write(
      userId: userId,
      type: 'approved',
      title: '✅ Admin Access Granted',
      body: 'You have been approved as an admin of "$orgName".',
      extra: {'orgName': orgName},
    );
  }

  /// Call when admin is demoted/revoked
  static Future<void> notifyDemoted({
    required String userId,
    required String orgName,
  }) async {
    await _write(
      userId: userId,
      type: 'demoted',
      title: '🔄 Admin Privileges Revoked',
      body: 'Your admin access for "$orgName" has been removed.',
      extra: {'orgName': orgName},
    );
  }

  /// Call when a member is removed from an organization
  static Future<void> notifyRemoved({
    required String userId,
    required String orgName,
  }) async {
    await _write(
      userId: userId,
      type: 'removed',
      title: '❌ Removed from Organization',
      body: 'You have been removed from "$orgName".',
      extra: {'orgName': orgName},
    );
  }

  // Unread count stream
  /// Stream that emits the count of unread notification
  static Stream<int> unreadCount(String userId) {
    return _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark a single notification as read
  static Future<void> markRead(String userId, String itemId) async {
    await _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .doc(itemId)
        .update({'read': true});
  }

  /// Mark all notifications as read
  static Future<void> markAllRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
